# دليل سير عمل Git (Git Workflow) - منصة (إسألني) التعليمية

يتبع فريق التطوير في منصة **(إسألني)** نظام **Git Flow** مبسط لضمان استقرار الكود المصدري وسهولة دمج الميزات التعليمية الجديدة دون التأثير على استقرار النظام (Production Stability).

## 1. استراتيجية الفروع (Branching Strategy)

*   **`main`**: فرع الإنتاج النهائي. يحتوي فقط على الكود المختبر والمستقر الذي يصل للطلاب والمعلمين.
*   **`develop`**: الفرع الرئيسي للتكامل (Integration). يتم فيه تجميع الميزات الجديدة واختبارها قبل الإطلاق.
*   **`feat/`**: فروع الميزات الجديدة (مثل: `feat/voice-notes`, `feat/file-encryption`). تنبثق من `develop`.
*   **`fix/`**: فروع إصلاح الأخطاء البرمجية (مثل: `fix/socket-timeout`).
*   **`hotfix/`**: إصلاحات طارئة لنسخة الإنتاج يتم دمجها مباشرة في `main` و `develop`.

## 2. بروتوكول الالتزام (Commit Convention)

نستخدم معايير **Conventional Commits** لتسهيل تتبع التغييرات المعرفية والتقنية:

*   **`feat(edu):`**: إضافة ميزة تعليمية جديدة (مثال: `feat(edu): إضافة دعم مشاركة ملفات PDF`).
*   **`fix(core):`**: إصلاح مشكلة تقنية في النواة (مثال: `fix(core): حل مشكلة انقطاع الإشارة في WebRTC`).
*   **`docs(api):`**: تحديث الوثائق البرمجية أو ملفات الـ docs.
*   **`refactor(ui):`**: تحسين هيكلية واجهة المستخدم دون تغيير وظيفتها.

## 3. الأوامر البرمجية المعتمدة (Git Commands)

### إنشاء ميزة تعليمية جديدة:
```bash
git checkout develop
git pull origin develop
git checkout -b feat/learning-feature-name
```

### مزامنة العمل مع الفريق:
```bash
git add .
git commit -m "feat(edu): وصف تقني للميزة الجديدة"
git push origin feat/learning-feature-name
```

### تحديث الفرع من `develop` لتجنب التعارضات (Conflicts):
```bash
git checkout develop
git pull origin develop
git checkout feat/learning-feature-name
git merge develop
```

## 4. مراجعة الكود (Code Review)
*   يجب فتح **Pull Request (PR)** عند الانتهاء من الميزة.
*   يجب مراجعة الكود من قبل مهندس آخر للتأكد من اتباع معايير الأمان (Security Audit) وسلامة منطق العمل (Business Logic).
*   يُمنع الدمج (Merge) قبل نجاح اختبارات البناء (Build Checks).
