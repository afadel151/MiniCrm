-- S0002__return_reason_codes.sql — fault attribution catalogue. Codes, default_fault and counts_against_cont
-- are transcribed from V1 spec §4.7 (return_reason_codes) and §5.5.2 (outcome classification); WRONG_NUMBER,
-- NEVER_ORDERED and BUSINESS_CANCELLED are not in §4.7's own (truncated, "...") example list but are needed to
-- represent two situations §5.5.2 names explicitly ("wrong number or 'I never ordered'" and "business cancels")
-- — added here, not themselves a literal transcription. Labels are drafts, not reviewed copy.

INSERT INTO return_reason_codes (key, fault_class, label_ar, label_fr, label_en) VALUES
  ('REFUSED_AT_DOOR', 'customer', 'رفض الاستلام', 'Refusé à la livraison', 'Refused at the door'),
  ('NOT_REACHABLE', 'customer', 'لا يمكن الوصول إليه', 'Injoignable', 'Not reachable'),
  ('ABSENT_REPEATED', 'customer', 'غائب بشكل متكرر', 'Absent à plusieurs reprises', 'Absent on repeated attempts'),
  ('WRONG_ADDRESS_BY_CUSTOMER', 'customer', 'عنوان خاطئ من العميل', 'Mauvaise adresse (client)', 'Wrong address supplied by customer'),
  ('CUSTOMER_CHANGED_MIND', 'customer', 'غير رأيه', 'A changé d''avis', 'Customer changed mind after confirming'),
  ('WRONG_ITEM_SENT', 'business', 'منتج خاطئ', 'Mauvais article envoyé', 'Wrong item sent'),
  ('LATE_DELIVERY', 'business', 'تأخير في التسليم', 'Livraison tardive', 'Late delivery'),
  ('DAMAGED', 'carrier', 'طرد تالف', 'Colis endommagé', 'Damaged in transit'),
  ('CARRIER_ISSUE', 'carrier', 'مشكلة في شركة التوصيل', 'Problème transporteur', 'Carrier issue'),
  ('WRONG_NUMBER', 'unknown', 'رقم خاطئ', 'Mauvais numéro', 'Wrong number'),
  ('NEVER_ORDERED', 'unknown', 'لم يطلب', 'N''a jamais commandé', 'Customer never ordered'),
  ('BUSINESS_CANCELLED', 'business', 'إلغاء من التاجر', 'Annulé par le marchand', 'Cancelled by the business');
