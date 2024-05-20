# weather_telegram_bot

## Bot registration

Need to find the @BotFather bot, write /start or /newbot to him, fill in the
fields he asks (bot name and short name), and receive a message with the bot
token and a link to the documentation. The token must be saved, preferably
securely, since this is the only key for authorizing the bot and interacting
with it.

## Installation

```
sudo sh ./weather_telegram_bot_installer.sh --install
```

Before installation, need to modify the `weather_telegram_bot.py` file and
replace `<open_weather_appip>` with open weather map appip, `<telegram_bot_token>`
with the telegram token for the bot.

## Deinstallation

```
sudo sh ./weather_telegram_bot_installer.sh --uninstall
```

## Dependencies

The bot requires `python3` and python package `pytelegrambotapi`.

