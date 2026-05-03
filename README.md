# מרחב — מערכת ניהול צוות ומשרד

מערכת web לניהול חדרים, עובדים, שיבוצים, חופשות ועבודה מהבית.  
קובץ HTML יחיד + Supabase כ-backend.

---

## מבנה הפרויקט

```
workspace-app/
├── index.html       ← האפליקציה המלאה
├── schema.sql       ← סכמת מסד הנתונים (הרץ פעם אחת ב-Supabase)
└── README.md        ← מסמך זה
```

---

## שלב 1 — הקמת Supabase

### 1.1 יצירת פרויקט
1. היכנס ל־ https://supabase.com → "New Project"
2. בחר שם לפרויקט (לדוגמה: `workspace-mgmt`)
3. הגדר סיסמת DB חזקה ושמור אותה
4. בחר region קרוב (לדוגמה: `eu-central-1` לאירופה)
5. לחץ "Create new project" — המתן כ-2 דקות

### 1.2 הרצת הסכמה
1. בתפריט השמאלי: **SQL Editor**
2. לחץ **"New query"**
3. פתח את הקובץ `schema.sql` והדבק את כל תוכנו
4. לחץ **Run** (▶)
5. וודא שמופיע "Success. No rows returned"

### 1.3 קבלת מפתחות ה-API
1. לך ל־ **Settings → API**
2. העתק את:
   - **Project URL** (נראה כמו `https://xxxx.supabase.co`)
   - **anon / public key** (מפתח ארוך מאוד)

---

## שלב 2 — חיבור האפליקציה

פתח את `index.html` בעורך טקסט.  
מצא את השורות הבאות (קרוב לתחתית הקובץ):

```javascript
const SUPABASE_URL = 'YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

החלף:
- `YOUR_SUPABASE_URL` ← ה-Project URL שהעתקת
- `YOUR_SUPABASE_ANON_KEY` ← ה-anon key שהעתקת

לדוגמה:
```javascript
const SUPABASE_URL = 'https://abcdefgh.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

---

## שלב 3 — יצירת המשתמש הראשון (Admin)

### 3.1 יצירת משתמש ב-Auth
1. ב-Supabase: **Authentication → Users → "Add user"** (Invite user)
2. הכנס אימייל וסיסמה זמנית
3. לחץ **"Create user"**
4. העתק את ה-**User UID** (UUID שמופיע ברשימה)

### 3.2 הוספת רשומת עובד
ב-**SQL Editor**, הרץ:

```sql
INSERT INTO employees (
  auth_user_id,
  full_name,
  email,
  role,
  group_id,
  is_active
) VALUES (
  'PASTE-USER-UID-HERE',           -- ה-UID מהשלב הקודם
  'שם המנהל',                      -- שם מלא בעברית
  'admin@yourcompany.com',         -- האימייל
  'admin',
  NULL,
  true
);
```

---

## שלב 4 — העלאה ל-GitHub Pages

### 4.1 יצירת repository
```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/workspace-app.git
git push -u origin main
```

### 4.2 הפעלת GitHub Pages
1. ב-GitHub: **Settings → Pages**
2. תחת **Source**: בחר `Deploy from a branch`
3. Branch: `main` / Root: `/ (root)`
4. לחץ **Save**
5. תוך ~2 דקות האתר יהיה זמין בכתובת:  
   `https://YOUR_USERNAME.github.io/workspace-app/`

### 4.3 חשוב — CORS ב-Supabase
1. לך ל-Supabase → **Settings → API**
2. תחת **Allowed origins**, הוסף את כתובת ה-GitHub Pages שלך:  
   `https://YOUR_USERNAME.github.io`

---

## שלב 5 — הוספת עובדים ראשונים

לאחר כניסה כ-Admin:

1. **עובדים** → "עובד חדש" — הוסף את כל 23 העובדים
2. שים לב להגדיר לכל עובד:
   - קבוצה (מנהלים / רכזות / זוטרות א / זוטרות ב)
   - חדר ראשי
   - ימי עבודה מהבית בשבוע

3. לאחר מכן, צור כניסות Auth לכל עובד שצריך גישה למערכת  
   (Authentication → Users → Add user), ועדכן את `auth_user_id` בטבלת `employees`

---

## תפקידים במערכת

| תפקיד | הרשאות |
|--------|---------|
| `admin` | גישה מלאה: עובדים, חדרים, מדיניות, אישור חופשות |
| `manager` | אישור חופשות ראשוני, שיבוץ עובדים, צפייה בדוחות |
| `employee` | בקשת חופשה, צפייה בלוח שנה |

---

## זרימת אישור חופשה

```
עובד שולח בקשה
       ↓
  [ממתין למנהל]
       ↓
  מנהל מאשר ← או → מנהל דוחה (סיום)
       ↓
 [ממתין לאדמין]
       ↓
  אדמין מאשר ← או → אדמין דוחה (סיום)
       ↓
    [אושר] ✓
  (נוצרים ימי חופשה אוטומטית בלוח)
```

---

## דרישות טכניות

- אין צורך ב-Node.js או build process
- עובד על כל browser מודרני (Chrome, Firefox, Safari, Edge)
- responsive לנייד (טאבלט ומעלה מומלץ לניהול)
- Supabase Free tier מספיק לצוות של 23 אנשים

---

## עדכונים ותחזוקה

כל עדכון לקוד:
```bash
git add .
git commit -m "תיאור השינוי"
git push
```
GitHub Pages מתעדכן אוטומטית תוך ~1 דקה.

---

## תמיכה ובאגים

לבעיות חיבור Supabase — בדוק:
1. SUPABASE_URL ו-ANON_KEY נכונים
2. כתובת GitHub Pages מוגדרת ב-Allowed Origins
3. סכמת ה-SQL הורצה בהצלחה (כל הטבלאות קיימות)
