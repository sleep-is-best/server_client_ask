# ERD - server_client_ask

هذا ملف ERD (مخطط العلاقة بين الكيانات) مقترح لمشروع "server_client_ask".
يصوّر الجداول الأساسية والعلاقات المتوقعة لتطبيق تعليمي آمن في الوقت الحقيقي مع دعم E2EE و WebRTC وتخزين محلي.

> ملاحظة: الحقول التي تحمل كلمات مثل "encrypted" أو مفاتيح التشفير تفترض أن القيم مخزنة مشفرة (E2EE) أو مشفرة على الجهاز.

```mermaid
erDiagram
  USERS {
    int id PK
    string uid "(UUID / auth id)"
    string name
    string email
    string role "student|mentor|admin"
    string avatar_url
    datetime created_at
    datetime updated_at
    string public_key "user public key for E2EE"
  }

  DEVICES {
    int id PK
    string device_id
    int user_id FK
    string platform
    string push_token
    datetime last_seen
  }

  CONTACTS {
    int id PK
    int owner_id FK
    int contact_user_id FK
    string alias
    datetime created_at
  }

  COURSES {
    int id PK
    string title
    string description
    int owner_id FK
    datetime created_at
  }

  LESSONS {
    int id PK
    int course_id FK
    string title
    text content
    int order_index
    datetime created_at
  }

  SESSIONS {
    int id PK
    int mentor_id FK
    int student_id FK
    int lesson_id FK
    datetime start_at
    datetime end_at
    string status "scheduled|live|ended|cancelled"
    string e2ee_session_key_encrypted "session key encrypted for participants"
    string sdp_offer
    string sdp_answer
  }

  MESSAGES {
    int id PK
    int session_id FK
    int sender_id FK
    text body_encrypted
    datetime sent_at
    bool delivered
    bool read
    string e2ee_nonce
  }

  CALLS {
    int id PK
    int session_id FK
    string webrtc_room_id
    string status "connecting|active|ended"
    datetime started_at
    datetime ended_at
  }

  MEDIA {
    int id PK
    int session_id FK
    int uploaded_by FK
    string media_type "audio|video|image|file"
    string url_encrypted
    string storage_key_encrypted
    datetime created_at
  }

  LOCAL_NOTES {
    int id PK
    int user_id FK
    string content_encrypted
    datetime updated_at
  }

  INVITES {
    int id PK
    int from_user_id FK
    int to_user_id FK
    int course_id FK
    string token_encrypted
    string status "pending|accepted|declined"
    datetime created_at
  }

  USERS ||--o{ DEVICES : owns
  USERS ||--o{ CONTACTS : has
  USERS ||--o{ COURSES : creates
  COURSES ||--o{ LESSONS : contains
  USERS ||--o{ SESSIONS : participates_in
  LESSONS ||--o{ SESSIONS : used_by
  SESSIONS ||--o{ MESSAGES : contains
  SESSIONS ||--o{ CALLS : hosts
  SESSIONS ||--o{ MEDIA : stores
  USERS ||--o{ LOCAL_NOTES : keeps
  USERS ||--o{ INVITES : sends
  COURSES ||--o{ INVITES : linked_to
```

## ملاحظات تنفيذية
- الحقول المؤشر عليها بـ `_encrypted` أو التي تمثل مفاتيح يجب أن تُخزن مشفّرة — إما على الخادم بشكل مشفر أو محليًا كجزء من E2EE.
- جداول `LOCAL_NOTES` و`Devices` تمثل بيانات محفوظة محليًا/على الجهاز؛ قد لا تُرسل كلها للخادم مشفّرة.
- يمكن تعديل هذا المخطط ليتناسب مع بنية API الحالية واشتقاقات SQLite المستخدمة في تطبيق Flutter.

---

تم إنشاء الملف بصيغة Markdown في مسار: `docs/ERD.md`
