# Топ-5 названий

1. **TryHackMe из РФ не коннектится: рабочий костыль, которого не было в гугле**
2. **Месяц искал, как зайти в лабы THM из России — пришлось изобретать самому**
3. **OpenVPN TryHackMe мёртв у провайдера? Happ + TCP 443 и снова учишься**
4. **Гайд, который я хотел найти сам: доступ к комнатам TryHackMe из РФ**
5. **Бросил THM, потому что VPN не поднимается? Не бросай — вот схема**

Рекомендация: **№1** для Хабра/vc.ru. **№5** — для Reddit/тех, кто уже сдался.

**Репо со скриптами:** https://github.com/Kystof91/thm-vpn-from-ru

---

# Короткий пост (Хабр / vc.ru / Reddit)

**Дисклеймер.** Это про доступ к *своим* учебным лабораториям TryHackMe (свой аккаунт/подписка). Не про взлом чужих систем. Делаете на свой страх и риск; соединение иногда отваливается — норма для такого костыля.

Скрипты (macOS + короткий Windows), без личных путей и без `.ovpn` с паролями:

**https://github.com/Kystof91/thm-vpn-from-ru**

---

Я долго пытался нормально учиться на TryHackMe из РФ.

Сайт открывается. Комната стартует. IP машины красиво светится на экране.  
А дальше — классика: OpenVPN либо не поднимается, либо «подключается» в никуда, либо отваливается так, будто ты лично оскорбил маршрутизатор провайдера.

Гугл, форумы, Reddit — везде одно и то же: «скачай .ovpn», «попробуй другой сервер», «у меня работает».  
У них работает. У тебя — нет. Особенно весело, когда ты уже готов страдать над nmap, а страдаешь над `Initialization Sequence`… который так и не Completed.

В какой-то момент хочется бросить THM и уйти в PortSwigger «потому что без VPN». Ресурсы нормальные. Но TryHackMe — отдельная вселенная, и обидно, что доступ упирается не в мозги, а в то, как у вас режут туннели.

## Что оказалось рабочим

Два слоя:

1. Снаружи — **Happ Plus** (системный VPN / TUN, не прокси «только для браузера»).
2. Внутри — **офифициальный OpenVPN TryHackMe**, профиль **TCP 443** (THM → Access → OpenVPN → EU-West TCP).

Порядок:

1. Happ Plus → Connect  
2. Свой `.ovpn` сохранить как `~/thm-vpn/thm-tcp.ovpn` (Windows: `%USERPROFILE%\thm-vpn\thm-tcp.ovpn`)  
3. Поднять OpenVPN **поверх** Happ  
4. Проверить доступ к IP машины из комнаты  

## Код: подключение (macOS)

Суть `connect-thm.command` — не дать запустить THM без Happ и указать путь к TCP-конфигу:

```bash
CONFIG="${THM_OVPN_CONFIG:-$HOME/thm-vpn/thm-tcp.ovpn}"

if ! pgrep -f "Happ.app" > /dev/null; then
    echo "Сначала Happ Plus → Connect, потом этот скрипт."
    exit 1
fi

if [ ! -f "$CONFIG" ]; then
    echo "Нет файла: $CONFIG"
    echo "Скачай TCP .ovpn с THM → Access → OpenVPN"
    exit 1
fi

sudo openvpn --config "$CONFIG" --verb 3
```

Полный файл: [`macos/connect-thm.command`](https://github.com/Kystof91/thm-vpn-from-ru/blob/main/macos/connect-thm.command)

## Код: отключение (macOS) — это важнее, чем кажется

Если просто убить Happ крестом, на Mac иногда остаётся «интернет умер» (залипший NECP kill-switch). Поэтому disconnect-скрипт делает по шагам: OpenVPN → штатный `scutil --nc stop` профиля Happ → quit приложения → сброс `nesessionmanager` → чистка прокси/DNS/DHCP → проверка сети.

Ключевой кусок:

```bash
# 1) THM
sudo killall openvpn 2>/dev/null || true

# 2) штатно гасим VPN-профиль Happ (не только pkill!)
scutil --nc stop "Happ Plus"

# 3) закрываем приложение
osascript -e 'tell application "Happ" to quit' 2>/dev/null || true

# 4) сброс Network Extension / kill-switch
sudo killall -9 nesessionmanager 2>/dev/null || true
sudo launchctl kickstart -k system/com.apple.nesessionmanager 2>/dev/null || true

# 5) прокси off + DNS с DHCP
sudo networksetup -setwebproxystate "Wi-Fi" off
sudo networksetup -setsecurewebproxystate "Wi-Fi" off
sudo networksetup -setsocksfirewallproxystate "Wi-Fi" off
sudo networksetup -setdnsservers "Wi-Fi" Empty
sudo ipconfig set en0 DHCP
```

Полный файл (с проверками интернета): [`macos/disconnect-thm.command`](https://github.com/Kystof91/thm-vpn-from-ru/blob/main/macos/disconnect-thm.command)

Мораль без сарказма: **сначала гасим THM, потом внешний VPN**, не наоборот в панике.

## Windows (коротко)

Тот же принцип. Хелперы в репо: `windows/connect-thm.bat`, `windows/disconnect-thm.bat`.

```bat
set "CONFIG=%USERPROFILE%\thm-vpn\thm-tcp.ovpn"
REM Happ Plus уже должен быть Connected
openvpn --config "%CONFIG%" --verb 3
```

Отключение: остановить `openvpn.exe`, затем **Disconnect в UI Happ**. Не End Task’ать Happ первым делом. Если сеть залипла — `ipconfig /flushdns`, при необходимости `netsh winsock reset` + ребут.

## Альтернативы, пока чините туннель

- PortSwigger Web Security Academy — бесплатно, без VPN  
- PicoCTF — через браузер  
- OverTheWire Bandit — SSH  
- Hack The Box + Pwnbox — браузерная машина  

Но если цель именно TryHackMe — схема выше у меня работает. Некрасиво. Зато учиться можно.

Репо: **https://github.com/Kystof91/thm-vpn-from-ru**

Если у вас из РФ THM тоже «висит на VPN» — напишите провайдер/ОС и что пробовали. Если есть решение элегантнее двух VPN — тоже пишите. Я искал месяцами и нашёл в основном тишину.

**TL;DR:** из РФ штатный OpenVPN THM часто мёртв → Happ Plus → поверх OpenVPN THM **TCP 443** → скрипты в репо. Отключать аккуратно. Иногда отваливается — переподключил и живёшь дальше.
