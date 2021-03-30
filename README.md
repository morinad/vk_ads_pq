# Кастомный коннектор к VK Ads для Power BI

### Наши курсы:
1) Основы Power BI (3 часа): https://directprorf.ru/basics?utm_source=github
2) Курс по коннекторам в Excel (4 часа): https://directprorf.ru/excel?utm_source=github
3) Большой курс по обработке данных в Power Query (8 часов): https://directprorf.ru/pq?utm_source=github
 
По всем вопросам, связанным с курсами и коннекторами: https://t.me/alexdirect или 89169787746.

### Как воспользоваться коннектором:

1) Скачайте файл MEZ: https://github.com/morinad/vk_ads_pq/raw/master/VKads.mez
2) Перенесите файлы в папку C:\Users\USERNAME\Documents\Power BI Desktop\Custom Connectors, подставив USERNAME своего компьютера.
3) Откройте Power BI, зайдите в Файл -> Параметры и настройки -> Параметры -> Глобальные -> Безопасность, выберите "Разрешить загрузку любого расширения без проверок и предупреждений".
4) Перезапустите Power BI. Нажмите на кнопку "Получить данные", в поиске введите "VK" и выберите коннектор VKads Connector. 

Если ссылка на получение токена не работает (она находится ниже), нужно создать своё приложение и подставить client_id=ВАШ_ИДЕНТИФИКАТОР_ПРИЛОЖЕНИЯ.

### Полезные ссылки:
Подробное видео по использованию коннектора: https://youtu.be/OkmRXuMDlbw

Получение токена: https://oauth.vk.com/authorize?client_id=7337090&display=page&redirect_uri=https://oauth.vk.com/blank.html&scope=ads,offline&response_type=token&v=5.130&state=123456

Создание приложения: https://vk.com/editapp?act=create (нужно выбирать standalone)

Справка API: https://vk.com/dev/manuals
