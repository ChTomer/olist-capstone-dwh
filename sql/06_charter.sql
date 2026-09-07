/* ============================================================================
   06_charter.sql - אמנת הפרויקט (Project Charter)
   ============================================================================

   רקע:
   דאטהסט Olist (מסחר אלקטרוני ברזילאי, Kaggle) - בניית DWH מלא מ-OLTP
   ל-OLAP, כולל דשבורד Power BI, כפרויקט גמר בקורס הנדסת/אנליטיקת נתונים.

   מטרות עסקיות - 5 כיווני ניתוח:
   1. ביצועי משלוחים (delivery performance) - עיכובים מול הערכה, זמני אספקה
   2. ניתוח מוכרים (seller analysis)
   3. פילוח גיאוגרפי (geographic segmentation)
   4. ביקורות לקוחות (customer reviews)
   5. התנהגות תשלומים (payment behavior)

   ארכיטקטורה - 3 שכבות:
   olist_db (מראה OLTP גולמית) -> olist_STG (ניקוי בלבד, ללא לוגיקה עסקית)
   -> olist_DWH (מודל ממדי - Fact Constellation)

   החלטת עיצוב מרכזית - Fact Constellation ולא Star יחיד:
   צירוף payment ו-review ברמת הזמנה לשורות ברמת item יצר כפילויות
   (fan-out) בסכומים ובממוצעים. הפתרון: 3 עובדות בגרעינים נפרדים:
     - Fact_Order_Items : grain = Order_ID + Order_Item_ID
     - Fact_Payments    : grain = Order_ID + Payment_Sequential
     - Fact_Reviews     : grain = Review_ID
   מחוברות דרך ממדים משותפים (Dim_Customer, Dim_Date) ודרך Order_ID
   כ-degenerate dimension לשאילתות drill-across.

   תיקון נוסף:
   Dim_Customer נבנה סביב Customer_Unique_ID בלבד (גרעין = אדם, ללא כתובת
   - כתובת משתנה בין הזמנות ולכן לא שייכת לישות "אדם"). כתובת המשלוח
   עברה ל-Dim_Order_Address נפרדת בגרעין Customer_ID. כתובות מוכרים
   נשארות ב-Dim_Seller נפרדת - שתי ישויות מבניות שונות למרות עמודות דומות.

   מחוץ לתחום (Out of Scope):
   - עדכוני מחירים/מלאי בזמן אמת (הדאטהסט היסטורי וסטטי)
   - אינטגרציה עם מקורות חיצוניים מעבר ל-Kaggle CSV
   - שכבת אבטחה/הרשאות מתקדמת

   קריטריוני הצלחה:
   - כל Fact טעון בגרעין הנכון (ר' 13_run_and_verify.sql)
   - סכומי Payment_Value וממוצעי Review_Score תואמים למקור ללא ניפוח
   - דשבורד Power BI פועל מעל olist_DWH במצב Import
   ============================================================================ */

-- קובץ תיעודי בלבד - אין כאן קוד להרצה
