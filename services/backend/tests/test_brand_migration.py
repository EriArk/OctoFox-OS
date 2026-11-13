"""Rename existing first-party offers without changing commercial identity."""
import psycopg
from psycopg.rows import dict_row
from trainer_backend.db import migrations


def test_existing_offers_keep_ids_prices_and_receipts(postgres):
    migration = next(sql for name, _, sql in migrations() if name == '0020_octofox_brand.sql')
    with psycopg.connect(postgres[0], row_factory=dict_row) as conn:
        # Recreate the pre-rename display values inside a rolled-back transaction.
        conn.execute("UPDATE trainer_backend.shop_offers SET publisher='TrainerOS' WHERE application='traineros'")
        conn.execute("UPDATE trainer_backend.shop_offers SET application='third-party' WHERE id='profile.orbit'")
        before = conn.execute('SELECT * FROM trainer_backend.shop_offers ORDER BY id').fetchall()
        receipts = conn.execute('SELECT * FROM trainer_backend.purchases ORDER BY id').fetchall()
        conn.execute(migration)
        after = conn.execute('SELECT * FROM trainer_backend.shop_offers ORDER BY id').fetchall()
        for old, new in zip(before, after, strict=True):
            expected = dict(old)
            if old['application'] == 'traineros': expected['publisher'] = 'OctoFox OS'
            assert new == expected
        assert conn.execute('SELECT * FROM trainer_backend.purchases ORDER BY id').fetchall() == receipts
        conn.execute(migration)
        assert conn.execute('SELECT * FROM trainer_backend.shop_offers ORDER BY id').fetchall() == after
        conn.rollback()
