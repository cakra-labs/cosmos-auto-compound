#!/bin/bash -e

# This script comes without warranties of any kind. Use at your own risk.

# The purpose of this script is to redelegate staking rewards to an appointed validator. This way you can reinvest (compound) rewards.

# Requirements: uptickd, curl and jq must be in the path.


##############################################################################################################################################################
# User settings.
##############################################################################################################################################################

KEY=${1}                                  # This is the key you wish to use for signing transactions, listed in first column of "gaiad keys list".
PASSPHRASE=${2}                           # Only populate if you want to run the script periodically. This is UNSAFE and should only be done if you know what you are doing.
DENOM="auptick"                           # Coin denominator is auptick. 1 uptick = 1000000000000000000 auptick.
VALIDATOR="uptickvaloper1ft8rpsax06kuvs8lyc38nqnkmm4teua8wxkflq"        # Default is Validator Network.

##############################################################################################################################################################


##############################################################################################################################################################
# Sensible defaults.
##############################################################################################################################################################

CHAIN_ID="uptick_117-1"                                     # Current chain id. Empty means auto-detect.
NODE="http://uptick.rpc.m.stavr.tech:3157"  # Either run a local full node or choose one you trust.
FEES="2200000000000000auptick"                         # Gas prices to pay for transaction.
GAS_FLAGS="--gas auto --fees ${FEES}"
CHAIN_BIN=uptickd
BROADCAST_MODE=sync
##############################################################################################################################################################


# Get information about key
KEY_STATUS=$(echo ${PASSPHRASE} | $CHAIN_BIN keys show ${KEY} --output json)
KEY_TYPE=$(echo ${KEY_STATUS} | jq -r ".type")


# Get current account balance.
ACCOUNT_ADDRESS=$(echo ${KEY_STATUS} | jq -r ".address")
ACCOUNT_STATUS=$($CHAIN_BIN q auth account ${ACCOUNT_ADDRESS} --node ${NODE} --output json)
ACCOUNT_SEQUENCE=$(echo ${ACCOUNT_STATUS} | jq -r ".sequence")
ACCOUNT_BANK=$($CHAIN_BIN q bank balances ${ACCOUNT_ADDRESS} --node ${NODE} --output json)
ACCOUNT_BALANCE=$(echo ${ACCOUNT_BANK} | jq -r ".balances[] | select(.denom == \"${DENOM}\") | .amount" || true)
if [ -z "${ACCOUNT_BALANCE}" ]
then
    # Empty response means zero balance.
    ACCOUNT_BALANCE=0
fi

# Get available rewards.
REWARDS_STATUS=$($CHAIN_BIN q distribution rewards ${ACCOUNT_ADDRESS} ${VALIDATOR} --node ${NODE} --output json)
if [ "${REWARDS_STATUS}" == "null" ]
then
    # Empty response means zero balance.
    REWARDS_BALANCE="0"
else
    REWARDS_BALANCE=$(echo ${REWARDS_STATUS} | jq -r ".rewards[] | select(.denom == \"${DENOM}\") | .amount" || true)
    if [ -z "${REWARDS_BALANCE}" ] || [ "${REWARDS_BALANCE}" == "null" ]
    then
        # Empty response means zero balance.
        REWARDS_BALANCE="0"
    else
        # Remove decimals.
        REWARDS_BALANCE=${REWARDS_BALANCE%.*}
    fi
fi

# Display what we know so far.
echo "======================================================"
echo "Account: ${KEY} (${KEY_TYPE})"
echo "Address: ${ACCOUNT_ADDRESS}"
echo "======================================================"
echo "Account balance:      ${ACCOUNT_BALANCE}${DENOM}"
echo "Available rewards:    ${REWARDS_BALANCE}${DENOM}"
echo

# Auto-detect chain-id if not specified.
if [ -z "${CHAIN_ID}" ]
then
  NODE_STATUS=$(curl -s --max-time 5 ${NODE}/status)
  CHAIN_ID=$(echo ${NODE_STATUS} | jq -r ".result.node_info.network")
fi

# Display delegation information.
VALIDATOR_STATUS=$($CHAIN_BIN q staking validator ${VALIDATOR} --node ${NODE} --output json)
VALIDATOR_MONIKER=$(echo ${VALIDATOR_STATUS} | jq -r ".description.moniker")
VALIDATOR_DETAILS=$(echo ${VALIDATOR_STATUS} | jq -r ".description.details")
echo "You are about to delegate ${REWARDS_BALANCE}${DENOM} to ${VALIDATOR}:"
echo "  Moniker: ${VALIDATOR_MONIKER}"
echo "  Details: ${VALIDATOR_DETAILS}"
echo

printf "Delegating... "
echo ${PASSPHRASE} | $CHAIN_BIN tx staking delegate ${VALIDATOR} ${REWARDS_BALANCE}${DENOM} --yes --from ${KEY} --chain-id ${CHAIN_ID} --node ${NODE} ${GAS_FLAGS} --broadcast-mode ${BROADCAST_MODE}

echo
echo "Have a Cosmic day!"
