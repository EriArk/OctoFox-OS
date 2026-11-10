"""Explicitly run only in the isolated rollback-check image, with fixture PostgreSQL."""
from uuid import uuid4
import pytest
from trainer_backend.accounts.provider import AuthError
from trainer_backend.economy.rollback_shop import Shop as RollbackShop
from test_accounts import account
from test_bazaar import prepared,buy,DETAILS


def test_rollback_preserves_paid_place_and_rejects_new_stall_purchase(account,postgres):
    shop,owner,bazaars=prepared(account,postgres);token=owner['access_token']
    buy(shop,token);bazaars.create(token,DETAILS)
    operation=uuid4();paid=shop.purchase(token,operation,'bazaar.stall',1,500)
    rollback=RollbackShop(shop.progression)
    assert rollback.snapshot(token,operation)['purchased_place']==paid['purchased_place']
    assert rollback.purchase(token,operation,'bazaar.stall',1,500)['purchased_place']==paid['purchased_place']
    with pytest.raises(AuthError,match='offer_unavailable'):rollback.purchase(token,uuid4(),'bazaar.stall',1,500)
    assert shop.progression.snapshot(token)['balance']==4500
