import os
import asyncio
import logging
import pytest

from starkware.starknet.testing.starknet import Starknet
from utils import Signer

logger = logging.getLogger(__name__)

ACCOUNT_CONTRACT = os.path.join(
    os.path.dirname(__file__), "../contracts/account/Account.cairo"
)

@pytest.fixture(scope="module")
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture(scope="module")
async def starknet_factory():
    starknet = await Starknet.empty()
    logger.info("Local StarkNet instance launched successfully")
    return starknet

@pytest.fixture(scope="module")
async def signer_factory():
    signer = Signer(123456789)
    return signer

@pytest.fixture(scope="module")
async def account_factory(starknet_factory, signer_factory):
    starknet = starknet_factory
    signer = signer_factory
    user_account = await starknet.deploy(
        source=ACCOUNT_CONTRACT,
        constructor_calldata=[signer.public_key]
    )
    logger.info(f"SmartAccount contract deployed: {hex(user_account.contract_address)}")

    return user_account, user_account.contract_address