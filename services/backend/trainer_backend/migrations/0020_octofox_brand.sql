-- SPDX-License-Identifier: GPL-3.0-or-later
-- Public publisher only: offer IDs, application identity, receipts and prices stay intact.
UPDATE trainer_backend.shop_offers SET publisher='OctoFox OS'
WHERE application='traineros' AND publisher='TrainerOS';
