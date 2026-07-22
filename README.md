# TryHackMe VPN из РФ — рабочий костыль

Штатный OpenVPN TryHackMe из России часто **не поднимается** или «коннектится в никуда».  
Рабочая схема: **сначала Happ Plus (внешний VPN) → поверх него OpenVPN THM по TCP 443**.

Репозиторий — скрипты + короткая инструкция. Без магии, с оговорками.

> **Дисклеймер.** Только для доступа к *своим* учебным лабораториям TryHackMe (свой аккаунт/подписка). Не для атак на чужие системы. Всё на свой страх и риск. Туннель иногда отваливается — это ожидаемо для такого костыля.

## Скачать скрипты

Не нужно разбираться в git. Скачай файлы и положи в папку `~/thm-vpn/` (Windows: `%USERPROFILE%\thm-vpn\`).

### Вариант А — весь архив одним кликом

📦 **[Скачать ZIP всего репозитория](https://github.com/Kystof91/thm-vpn-from-ru/archive/refs/heads/main.zip)**

Распакуй → зайди в `macos/` или `windows/` → запускай нужный файл.

### Вариант Б — отдельные файлы (правой кнопкой → «Сохранить как…»)

**macOS**

| Файл | Ссылка |
|------|--------|
| Подключить THM | [connect-thm.command](https://raw.githubusercontent.com/Kystof91/thm-vpn-from-ru/main/macos/connect-thm.command) |
| Отключить + починить интернет | [disconnect-thm.command](https://raw.githubusercontent.com/Kystof91/thm-vpn-from-ru/main/macos/disconnect-thm.command) |

После скачивания в Терминале один раз:

```bash
mkdir -p ~/thm-vpn
chmod +x ~/thm-vpn/connect-thm.command ~/thm-vpn/disconnect-thm.command
```

(если сохранил файлы в другую папку — поправь пути в `chmod`)

**Windows**

| Файл | Ссылка |
|------|--------|
| Подключить THM | [connect-thm.bat](https://raw.githubusercontent.com/Kystof91/thm-vpn-from-ru/main/windows/connect-thm.bat) |
| Отключить | [disconnect-thm.bat](https://raw.githubusercontent.com/Kystof91/thm-vpn-from-ru/main/windows/disconnect-thm.bat) |

⚠️ Свой `.ovpn` с сайта THM **сюда не входит** — его скачиваешь только из кабинета TryHackMe (там логин/ключ). Клади рядом: `~/thm-vpn/thm-tcp.ovpn`.

## Почему так

1. У части провайдеров в РФ OpenVPN (особенно UDP / «голый» профиль) чувствует себя плохо.
2. TCP 443 до VPN THM, проложенный **уже из** нормального системного VPN (Happ Plus), чаще доезжает.
3. Порядок слоёв критичен. Сначала внешний VPN, потом THM. Не наоборот.

Happ Plus здесь указан **конкретно** — на нём схема проверена. Подойдёт идея «любой полный TUN/system VPN», но гайд заточен под Happ.

## Быстрый старт (macOS)

### 0. Подготовка

1. **[Скачай скрипты](#скачать-скрипты)** (ZIP или отдельные файлы) → в `~/thm-vpn/`.
2. Установи [OpenVPN](https://openvpn.net/community-downloads/) (CLI: `brew install openvpn` или чтобы `openvpn` был в PATH).
3. Установи **Happ Plus**, подключись, проверь что интернет через него живой.
4. На сайте THM: **Access → OpenVPN → скачай TCP-профиль (EU-West / TCP 443)**.
5. Сохрани конфиг как:

```text
~/thm-vpn/thm-tcp.ovpn
```

⚠️ В `.ovpn` есть твои учётки — **никому не отправляй**.

### 1. Подключение

```text
1) Happ Plus → Connect
2) двойной клик по connect-thm.command
   (или: bash ~/thm-vpn/connect-thm.command)
3) дождись Initialization Sequence Completed
4) в комнате THM проверь доступ к IP машины
```

Скрипт сам проверит, что Happ запущен и что конфиг лежит на месте.

Переменная на случай другого пути к конфигу:

```bash
export THM_OVPN_CONFIG="$HOME/thm-vpn/thm-tcp.ovpn"
```

### 2. Отключение (важно)

Не убивай Happ крестом в первую очередь — на macOS бывает **залипает NECP kill-switch** («интернет умер до перезагрузки»).

```text
1) Ctrl+C в окне OpenVPN (или закрой окно connect-скрипта)
2) двойной клик / запуск disconnect-thm.command
```

Скрипт по шагам:

1. гасит OpenVPN  
2. штатно `scutil --nc stop` для профиля Happ Plus  
3. закрывает приложение  
4. сбрасывает Network Extension / NECP  
5. чистит прокси/DNS, обновляет DHCP  
6. проверяет обычный интернет  

Опционально под себя:

```bash
export WIFI_SERVICE="Wi-Fi"      # или "Ethernet"
export PRIMARY_IF="en0"
export LAN_GATEWAY="192.168.0.1" # IP твоего роутера
export HAPP_VPN_NAME="Happ Plus"
```

## Windows (коротко)

Тот же принцип, без магии NECP.

1. Happ Plus → Connect  
2. OpenVPN GUI / `windows/connect-thm.bat` с конфигом:

```text
%USERPROFILE%\thm-vpn\thm-tcp.ovpn
```

3. Отключение: сначала OpenVPN (`windows/disconnect-thm.bat` или Exit в GUI), **потом** Disconnect в UI Happ.  
4. Если интернет залип: `ipconfig /flushdns`, при необходимости `netsh winsock reset` + ребут.

## Структура репо

```text
macos/
  connect-thm.command      # подключение THM поверх Happ
  disconnect-thm.command   # безопасный разбор слоёв + восстановление сети
windows/
  connect-thm.bat
  disconnect-thm.bat
```

## Типичные проблемы

| Симптом | Что проверить |
|--------|----------------|
| OpenVPN не коннектится | Happ точно подключен? Взят **TCP 443**, не UDP? |
| VPN «зелёный», до машины не пингуется | Порядок слоёв; иногда переподключить оба |
| После отключения нет интернета (Mac) | `disconnect-thm.command`; в крайнем случае Connect→Disconnect в Happ UI или ребут |
| Иногда само отваливается | Да, бывает. Переподключил два слоя — ок для учёбы |

## Альтернативы без VPN THM

Если прямо сейчас не хочется танцевать с туннелями:

- [PortSwigger Web Security Academy](https://portswigger.net/web-security) — бесплатно, без VPN  
- [PicoCTF](https://picoctf.org) — через браузер  
- [OverTheWire Bandit](https://overthewire.org/wargames/bandit) — SSH  
- Hack The Box + Pwnbox — браузерная машина  

## Лицензия

MIT. Скрипты «as is». Если нашли способ элегантнее двух VPN — PR/Issue приветствуются.
