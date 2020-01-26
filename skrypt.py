#!/usr/bin/python
import tweepy
from tweepy import OAuthHandler
from tweepy import Stream
from tweepy.streaming import StreamListener
import unicodedata
import json
import datetime
from urllib3.exceptions import ProtocolError

consumer_key = ''
consumer_secret = ''
access_token = ''
access_secret = ''
 
auth = OAuthHandler(consumer_key, consumer_secret)
auth.set_access_token(access_token, access_secret)
 
api = tweepy.API(auth)




class MyListener(StreamListener):
 

    def on_status(self, status):
        print (status.text)

    def on_data(self, data):

        dt = datetime.datetime.now()
        plik = 'TwitterData_%s_%s_%s.json' % (dt.year, dt.month, dt.day)
        
        try:
            if ('"coordinates":null' not in data):
                json_data = json.loads(data)
                with open(plik, 'a', encoding='utf-8') as f:
                    f.write(json.dumps(json_data,ensure_ascii=False)+"\n")
            
                    return True
        except BaseException as e:
            print("Error on_data: %s" % str(e))
            time.sleep(15*60)
            pass
            
        return True
 
    def on_error(self, status):
        print(status)
        return True
    def on_timeout(self):
        print >> sys.stderr, 'Timeout...'
        return True # Don't kill the stream

sapi = tweepy.streaming.Stream(auth, MyListener())    
sapi.filter(locations=[14.12289,49.00205,24.14578,54.83642])

def process_or_store(tweet):
    print(json.dumps(tweet))


twitter_stream = Stream(auth, MyListener())
