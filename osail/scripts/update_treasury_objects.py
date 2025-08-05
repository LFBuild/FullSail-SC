#!/usr/bin/env python3
import re
import os

def extract_treasury_caps_from_sql():
    """
    Извлекает treasury_cap из файла insert_osail.sql
    """
    try:
        with open('insert_osail.sql', 'r') as f:
            content = f.read()
    except FileNotFoundError:
        print("Ошибка: файл 'insert_osail.sql' не найден.")
        return None

    # Регулярное выражение для извлечения treasury_cap из каждой строки VALUES
    # Ищем паттерн: (epoch, 'token_address', 'treasury_cap', 'coin_metadata')
    treasury_caps = []
    
    # Разбиваем на строки и ищем строки с VALUES
    lines = content.split('\n')
    for line in lines:
        line = line.strip()
        if line.startswith('(') and (line.endswith('),') or line.endswith(');')):
            # Извлекаем третий элемент (treasury_cap) из строки
            # Формат: (epoch, 'token_address', 'treasury_cap', 'coin_metadata')
            # Убираем запятую или точку с запятой в конце
            clean_line = line.rstrip(',').rstrip(';').strip('()')
            parts = clean_line.split(', ')
            if len(parts) >= 4:
                treasury_cap = parts[2].strip("'")
                treasury_caps.append(treasury_cap)
    
    return treasury_caps

def update_transfer_script(treasury_caps):
    """
    Обновляет transfer_osail_treasury.sh с новыми treasury_cap
    """
    try:
        with open('transfer_osail_treasury.sh', 'r') as f:
            content = f.read()
    except FileNotFoundError:
        print("Ошибка: файл 'transfer_osail_treasury.sh' не найден.")
        return False

    # Обновляем файл без создания резервной копии

    # Обновляем каждую строку OBJECT
    updated_content = content
    for i, treasury_cap in enumerate(treasury_caps, 1):
        old_pattern = rf'export OBJECT{i}=[^\n]+'
        new_line = f'export OBJECT{i}={treasury_cap}'
        updated_content = re.sub(old_pattern, new_line, updated_content)

    # Записываем обновленный файл
    try:
        with open('transfer_osail_treasury.sh', 'w') as f:
            f.write(updated_content)
        print("Файл transfer_osail_treasury.sh успешно обновлен!")
        return True
    except IOError as e:
        print(f"Ошибка записи в файл: {e}")
        return False

def main():
    print("Извлечение treasury_cap из insert_osail.sql...")
    treasury_caps = extract_treasury_caps_from_sql()
    
    if not treasury_caps:
        print("Не удалось извлечь treasury_cap из SQL файла.")
        return
    
    print(f"Найдено {len(treasury_caps)} treasury_cap:")
    for i, cap in enumerate(treasury_caps, 1):
        print(f"OBJECT{i}: {cap}")
    
    print("\nОбновление transfer_osail_treasury.sh...")
    if update_transfer_script(treasury_caps):
        print("Скрипт успешно обновлен!")
    else:
        print("Ошибка при обновлении скрипта.")

if __name__ == "__main__":
    main() 