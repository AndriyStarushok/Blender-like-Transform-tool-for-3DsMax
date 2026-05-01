Blender Transform Engine for 3ds Max (V25)

Complete User Guide & Installation Manual

🇬🇧 ENGLISH VERSION

1. Installation

This tool consists of two files: the logic engine (.ms) and the interface macros (.mcr).

Engine File (BlenderGrab_Engine.ms):
Copy this file into your 3ds Max Startup scripts folder so it loads automatically.
Path: C:\Program Files\Autodesk\3ds Max 202X\scripts\startup
(Alternatively: %localappdata%\Autodesk\3dsMax\202X - 64bit\ENU\scripts\startup)

Macros File (BlenderGrab.mcr):
Copy this file into your User Macros folder.
Path: %localappdata%\Autodesk\3dsMax\202X - 64bit\ENU\usermacros

Restart 3ds Max.

2. Assigning Hotkeys

To get the true Blender experience, you need to assign standard Blender hotkeys to these tools.

Open 3ds Max and go to Customize -> Hotkey Editor.

In the Search bar, type Blender or find the category "Custom Tools".

Assign the following hotkeys:

Blender Transform Engine ➔ Assign to G

Blender Duplicate ➔ Assign to Shift+D

Blender Repeat ➔ Assign to Shift+R

Blender Grab From Point ➔ Assign to Shift+G (or whatever you prefer)

Optional: Find "Full Blender Mode Toggle" and drag it to your main toolbar. This button allows you to toggle the aggressive interception of G/R/S keys.

3. How to Use

Basic Transformations

Select an object or sub-objects (vertices, edges, polygons) and press G to instantly start moving it (Grab).

While the tool is active, press R to switch to Rotation, or S to switch to Scaling.

Click Left Mouse Button (LMB) or press Enter to confirm.

Click Right Mouse Button (RMB) or press Esc to cancel and return the object to its original position.

Axes Constraints

While moving, rotating, or scaling, you can lock the action to a specific axis:

Press X, Y, or Z to lock to the Global Axis.

Press X, Y, or Z again to lock to the Local Axis of the object.

Press the axis key a third time to return to Free Move.

Press Shift+X, Shift+Y, or Shift+Z to lock to a plane (e.g., Shift+Z will move the object only on the X and Y axes, ignoring Z).

Numeric Input

You can type exact values with your keyboard during any transformation!

Example 1: Press G, then X, then type 50, then press Enter. The object will move exactly 50 units along the X-axis.

Example 2: Press S, type 50, press Enter. The object will scale to 50% (half its size).

Use the - (minus) key for negative values and . (dot) for decimals. Press Backspace to correct typos.

Advanced Features

Snapping (Ctrl): Press Ctrl while moving to quickly toggle 3ds Max Snapping (magnet) on and off.

Grab From Point (Shift+G): Select an object/vertices, press Shift+G. The script will calculate the nearest vertex to your mouse cursor, snap your mouse exactly to it, and start the Grab tool automatically. Perfect for precise vertex snapping!

Duplicate (Shift+D): Select an object or polygons and press Shift+D. It instantly creates a clone and automatically enters the Grab mode.

Repeat Action (Shift+R): Applies your last exact transformation to the current selection. If your last action was "Duplicate and Move 100mm up", Shift+R will duplicate the new selection and move it 100mm up again! Works flawlessly with Instances.

Gizmo & FFD Support: You can enter sub-object mode on modifiers like UVW Map, Bend, Symmetry, or FFD, select the Gizmo or Control Points, and use G/R/S directly on them!

🇺🇦 УКРАЇНСЬКА ВЕРСІЯ

1. Встановлення

Цей інструмент складається з двох файлів: логічного рушія (.ms) та макросів інтерфейсу (.mcr).

Файл рушія (BlenderGrab_Engine.ms):
Скопіюйте цей файл у папку автозавантаження скриптів 3ds Max.
Шлях: C:\Program Files\Autodesk\3ds Max 202X\scripts\startup
(Або: %localappdata%\Autodesk\3dsMax\202X - 64bit\ENU\scripts\startup)

Файл макросів (BlenderGrab.mcr):
Скопіюйте цей файл у папку макросів користувача.
Шлях: %localappdata%\Autodesk\3dsMax\202X - 64bit\ENU\usermacros

Перезапустіть 3ds Max.

2. Призначення гарячих клавіш

Щоб отримати справжній досвід Blender, вам потрібно призначити стандартні клавіші.

Відкрийте 3ds Max і перейдіть до Customize -> Hotkey Editor.

У рядку пошуку введіть Blender або знайдіть категорію "Custom Tools".

Призначте наступні клавіші:

Blender Transform Engine ➔ Призначити на G

Blender Duplicate ➔ Призначити на Shift+D

Blender Repeat ➔ Призначити на Shift+R

Blender Grab From Point ➔ Призначити на Shift+G (або іншу зручну вам клавішу)

Опціонально: Знайдіть "Full Blender Mode Toggle" і перетягніть цю кнопку на вашу головну панель інструментів (Toolbar). Вона дозволяє вмикати/вимикати агресивне перехоплення клавіш G/R/S.

3. Як користуватися

Базові трансформації

Виділіть об'єкт або під-об'єкти (точки, ребра, полігони) і натисніть G, щоб миттєво почати переміщення (Grab).

Під час роботи інструмента натисніть R, щоб перейти до Обертання (Rotate), або S для Масштабування (Scale).

Натисніть Ліву кнопку миші (LMB) або Enter, щоб застосувати зміни.

Натисніть Праву кнопку миші (RMB) або Esc, щоб скасувати дію і повернути об'єкт на початкове місце.

Блокування по осях (Constraints)

Під час переміщення, обертання або масштабування ви можете заблокувати дію по певній осі:

Натисніть X, Y або Z для блокування по Глобальній осі.

Натисніть X, Y або Z ще раз для блокування по Локальній осі об'єкта.

Натисніть клавішу осі втретє, щоб повернутися до Вільного руху (Free Move).

Натисніть Shift+X, Shift+Y або Shift+Z для блокування по площині (наприклад, Shift+Z дозволить рухати об'єкт лише по осях X та Y, ігноруючи висоту Z).

Цифрове введення (Numeric Input)

Ви можете вводити точні значення з клавіатури прямо під час трансформації!

Приклад 1: Натисніть G, потім X, введіть 50, потім натисніть Enter. Об'єкт зміститься рівно на 50 одиниць по осі X.

Приклад 2: Натисніть S, введіть 50, натисніть Enter. Об'єкт зменшиться до 50% (вдвічі).

Використовуйте клавішу - (мінус) для від'ємних значень та . (крапку) для десяткових дробів. Клавіша Backspace видаляє помилки.

Просунуті функції

Прив'язка (Ctrl): Натисніть Ctrl під час руху, щоб швидко увімкнути або вимкнути стандартний магніт 3ds Max (Snapping).

Схопити за найближчу точку (Shift+G): Виділіть об'єкт/точки і натисніть Shift+G. Скрипт знайде найближчий до вашого курсора вертекс, миттєво "телепортує" мишку до нього і почне переміщення. Ідеально для точної прив'язки!

Дублювання (Shift+D): Виділіть об'єкт або полігони і натисніть Shift+D. Це миттєво створить клони і автоматично активує режим переміщення.

Повторення дії (Shift+R): Застосовує вашу останню точну трансформацію до поточного виділення. Якщо ваша остання дія була "Дублювати і підняти на 100мм", Shift+R продублює нове виділення і також підніме його на 100мм! Працює бездоганно навіть з Instance-копіями.

Підтримка Gizmo та FFD: Ви можете зайти в режим під-об'єктів для модифікаторів (наприклад, UVW Map, Bend, Symmetry або FFD), виділити контейнер Gizmo або контрольні точки, і використовувати G/R/S прямо на них!