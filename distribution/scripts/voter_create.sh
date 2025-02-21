source ./export.sh

sui client ptb \
--move-call std::type_name::get "<$FULLSAIL_TOKEN_TYPE>" \
--assign fullsail_token_type \
--move-call std::vector::singleton '<std::type_name::TypeName>' fullsail_token_type \
--assign fullsail_token_type_vector \
--move-call $PACKAGE::voter::create "<$FULLSAIL_TOKEN_TYPE>" @$VOTER_PUBLISHER fullsail_token_type_vector \
--assign voter_and_notify_cap \
--move-call sui::transfer::public_share_object "<$PACKAGE::voter::Voter<$FULLSAIL_TOKEN_TYPE>>" voter_and_notify_cap.0 \
--transfer-objects '[voter_and_notify_cap.1]' @$ADDR

# last tx id https://suivision.xyz/txblock/3PMAigdWiaPm3mt7sbTjffGXzA9f6zytjoqTbcR9myrr?tab=Changes