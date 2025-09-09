source ./export.sh


export WHO=0x2b0a9b6b91c79e5c6953871578dc283a5bfbf7c5d619a9314411f983f959c9db

sui client ptb \
--move-call $PACKAGE::price_monitor::add_admin @$SUPER_ADMIN_CAP @$MONITOR @$WHO