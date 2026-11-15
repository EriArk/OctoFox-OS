-- SPDX-License-Identifier: GPL-3.0-or-later
-- The official venue has a real owner but does not consume that player's one
-- purchased personal Bazaar. Only the migration/operator role can provision it.
ALTER TABLE trainer_backend.bazaars ADD COLUMN kind text NOT NULL DEFAULT 'personal' CHECK(kind IN ('personal','official'));
ALTER TABLE trainer_backend.bazaars ALTER COLUMN offer_id DROP NOT NULL;
ALTER TABLE trainer_backend.bazaars DROP CONSTRAINT bazaars_owner_id_key;
ALTER TABLE trainer_backend.bazaars ADD CONSTRAINT bazaar_kind_license CHECK(
    (kind='personal' AND offer_id IS NOT NULL AND offer_id='bazaar.personal') OR
    (kind='official' AND offer_id IS NULL));
CREATE UNIQUE INDEX one_personal_bazaar ON trainer_backend.bazaars(owner_id) WHERE kind='personal';
CREATE OR REPLACE FUNCTION trainer_backend.provision_bazaar_stall(receipt uuid) RETURNS SETOF trainer_backend.bazaar_places
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,trainer_backend AS $$
    INSERT INTO trainer_backend.bazaar_places(id,bazaar_id,name,purchase_id)
    SELECT p.id,b.id,'Trading place ' || (SELECT count(*)+1 FROM trainer_backend.bazaar_places WHERE bazaar_id=b.id),p.id
    FROM trainer_backend.purchases p JOIN trainer_backend.bazaars b ON b.owner_id=p.player_id AND b.kind='personal'
    WHERE p.id=receipt AND p.offer_id='bazaar.stall'
    ON CONFLICT(purchase_id) DO NOTHING RETURNING *;
$$;
