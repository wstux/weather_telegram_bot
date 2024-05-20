import argparse
import ast
import logging
import requests
import telebot
from datetime import datetime
from datetime import timezone

APP_NAME = "weather_telegram_bot"
OPEN_WEATHER_APPIP = "<open_weather_appip>"
TELEGRAM_BOT_TOKEN = "<telegram_bot_token>"

bot = telebot.TeleBot(TELEGRAM_BOT_TOKEN)

def get_city(text):
    if text.startswith('/weather'):
        return text.replace("/weather ", "")
    elif text.startswith('/погода'):
        return text.replace("/погода ", "")
    return ""

def get_current_weather(city):
    try:
        res = requests.get("https://api.openweathermap.org/data/2.5/weather",
                           params={'q': city,
                                   'units': 'metric',
                                   'lang': 'ru',
                                   'appid': f'{OPEN_WEATHER_APPIP}'}
                          )
        data = res.json()
        rc = data['cod']
        if rc != 200 and rc != '200':
            return f"Invalid request. Reason: {data['message']}"
        temp = data['main']['temp']
        description = data['weather'][0]['description']
        return f"City: {city}\nWeather: {temp}°, {description}"
    except Exception as e:
        return f"Exception (weather): {e}"

def get_log_level(ll_str):
    if ll_str == 'debug':
        return logging.DEBUG
    elif ll_str == 'info':
        return logging.INFO
    elif ll_str == 'warning':
        return logging.WARNING
    elif ll_str == 'error':
        return logging.ERROR
    return logging.WARNING

def weather_request(message):
    city = get_city(message.text)
    logging.info(f"Request weather for city '{city}' from user '{message.from_user.id}'")
    keyboard = telebot.types.InlineKeyboardMarkup()
    key_current = telebot.types.InlineKeyboardButton(text='current', callback_data="['current','" + city + "']")
    key_today = telebot.types.InlineKeyboardButton(text='today', callback_data="['today','" + city + "']")
    key_tomorrow = telebot.types.InlineKeyboardButton(text='tomorrow', callback_data="['tomorrow','" + city + "']")
    keyboard.add(key_current)
    keyboard.add(key_today)
    keyboard.add(key_tomorrow)
    question = 'Please, select period'
    bot.send_message(message.from_user.id, text=question, reply_markup=keyboard)

@bot.message_handler(content_types=['text'])
def start(message):
    if message.text.startswith('/weather') or message.text.startswith('/погода'):
        weather_request(message)
    else:
        bot.send_message(message.from_user.id, 'Invalid command');

@bot.callback_query_handler(func=lambda call: True)
def callback_worker(call):
    logging.info(f"callback_warker: user id '{call.message.chat.id}', call.data '{call.data}'")
    try:
        call_type = ast.literal_eval(call.data)[0]
        city = ast.literal_eval(call.data)[1]
        weather = "Invalid request"
        if call_type == "current":
            weather = get_current_weather(city)
        elif call_type == "today":
            weather = "Sorry, this request unsupported now. Current wearher:\n"
            weather += get_current_weather(city)
        elif call_type == "tomorrow":
            weather = "Sorry, this request unsupported now. Current wearher:\n"
            weather += get_current_weather(city)
        bot.send_message(call.message.chat.id, weather)
    except Exception as e:
        logging.error(f"callback_warker: user id '{call.message.chat.id}', call.data '{call.data}'. Exception: '{e}'")
        pass


def main():
    parser = argparse.ArgumentParser(description="weather telegram bot")
    parser.add_argument("-l", "--loglevel", choices=['debug', 'info', 'warning', 'error'],
                        default='debug', help="logging level")
    args = parser.parse_args()

    loglevel = get_log_level(args.loglevel)
    logging.basicConfig(filename='/var/log/weather_telegram_bot.log', level=loglevel, format='%(asctime)s [%(levelname)s] : %(message)s')
    logging.info('Weather telegram bot started')
    bot.polling(none_stop=True, interval=0)

if __name__ == '__main__':
    main()

