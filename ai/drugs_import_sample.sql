BEGIN;

INSERT INTO medications.drugs (id, trade_name, international_name, atx_code, min_dose, max_dose, dose_unit, is_in_rag)
VALUES
    ('2ba3f097-2d5a-57a2-9c58-837ce64047cc', 'ПЕРСЕН НОЧЬ', 'Valerian, Melissa, Peppermint', 'N05CM', NULL, NULL, NULL, false),
    ('81d96701-484d-5fc6-bf1b-8cb363edbacf', 'ПОСТЕРИЗАН', NULL, 'C05AX03', NULL, NULL, NULL, false),
    ('1bb0b35e-5515-5dbe-be3d-504138753ace', 'ПОСТЕРИЗАН ФОРТЕ', NULL, 'C05AX03', NULL, NULL, NULL, false),
    ('663ab38a-381d-5814-af18-0a10f019699e', 'АТРОВЕНТ', 'ipratropium bromide', 'R03BB01', NULL, NULL, NULL, false),
    ('c26f74b0-0e11-5e61-b426-8718251b3121', 'АТРОВЕНТ Н', 'ipratropium bromide', 'R03BB01', NULL, NULL, NULL, false),
    ('a9625d94-adb8-5be7-858b-b714c617ad1a', 'БЕРОДУАЛ', 'fenoterol, ipratropium bromide', 'R03AL01', NULL, NULL, NULL, false),
    ('21d5cd77-9b5f-5329-b4db-816e5d13e8bc', 'БЕРОДУАЛ Н', 'fenoterol, ipratropium bromide', 'R03AL01', NULL, NULL, NULL, false),
    ('6f57fa1c-38b8-5928-847f-a36a19bd37d1', 'БЕРОТЕК Н', 'fenoterol', 'R03AC04', NULL, NULL, NULL, false),
    ('815318cd-fe79-5917-a09f-8cdee291a01c', 'СПИОЛТО РЕСПИМАТ', 'olodaterol, tiotropium bromide', 'R03AL06', NULL, NULL, NULL, false),
    ('3681f78a-a349-5556-a109-c3e80dcba548', 'СПИРИВА', 'tiotropium bromide', 'R03BB04', NULL, NULL, NULL, false),
    ('fa7c0e98-1fdb-5ef4-a803-25daea176556', 'СПИРИВА РЕСПИМАТ', 'tiotropium bromide', 'R03BB04', NULL, NULL, NULL, false),
    ('9a46466f-5611-502d-b389-0cd1e1eaac73', 'ТВИНСТА', 'amlodipine, telmisartan', 'C09DB04', NULL, NULL, NULL, false),
    ('6369adff-6285-5219-8e8d-eebd26e00f4d', 'АПИДРА СолоСтар', 'insulin glulisine', 'A10AB06', NULL, NULL, NULL, false),
    ('962063e9-d352-5cd7-8574-93d64e52feac', 'ЛАНТУС СолоСтар', 'insulin glargine', 'A10AE04', NULL, NULL, NULL, false),
    ('feabbd4e-c8aa-501a-aa0d-d39a0f1a20c8', 'КЛЕКСАН', 'enoxaparin sodium', 'B01AB05', NULL, NULL, NULL, false),
    ('80cc9389-dfb6-5b87-8b2c-8d692023c610', 'ЭРСЕФУРИЛ', 'nifuroxazide', 'A07AX03', NULL, NULL, NULL, false),
    ('55c868c1-4a52-571c-9bc5-f6b7632eb1ba', 'ЛАЙФЕВИТ', 'tocopherol', 'A11HA03', NULL, NULL, NULL, false),
    ('63f43a73-72bd-5c5a-8a05-5af4c658c20c', 'ИБЕРОГАСТ', NULL, 'A03AX', NULL, NULL, NULL, false),
    ('b0fe6274-ce73-5d07-805c-c509fe506687', 'РЕННИ', 'calcium carbonate, magnesium carbonate', 'A02AX', NULL, NULL, NULL, false),
    ('d819ce51-c8c4-599b-b209-4df8b37fbcd6', 'ГИСТАФЕН', 'sequifenadine', 'R06AX32', NULL, NULL, NULL, false)
ON CONFLICT (id) DO UPDATE
SET trade_name = EXCLUDED.trade_name,
    international_name = EXCLUDED.international_name,
    atx_code = EXCLUDED.atx_code,
    min_dose = EXCLUDED.min_dose,
    max_dose = EXCLUDED.max_dose,
    dose_unit = EXCLUDED.dose_unit,
    is_in_rag = EXCLUDED.is_in_rag,
    updated_at = NOW();

COMMIT;
