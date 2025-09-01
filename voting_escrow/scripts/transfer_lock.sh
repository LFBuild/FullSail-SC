#!/bin/bash

source ./export.sh

echo "Transferring lock to recipient..."

# Параметры для вызова transfer
SAIL_COIN_TYPE="0x03c89d9f1551b9015abd99801116b6e9e568347eabdd2a565cd606800a5ce7ce::SAIL::SAIL"
RECIPIENT="0x09c1c9d2597f88169f494ab5606a69a5946790cb1d9e3f9b53a7ac4c289791c6"
LOCK="0xd9c75461df433d904066c0fccc4e136c5b8457543f2ba8b4b18d6f4f14620bbc"
VOTING_ESCROW="0xf6a14331abbb4c7f9d0af57f1185202b933219d9017277479847fc20a6c175a0"

sui client ptb \
--move-call $PACKAGE::voting_escrow::transfer "<$SAIL_COIN_TYPE>" \
    @$LOCK \
    @$VOTING_ESCROW \
    @$RECIPIENT \
    @$CLOCK \
--gas-budget 10000000

echo "Lock transfer completed!"
