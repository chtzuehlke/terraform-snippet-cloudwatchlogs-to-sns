#!/bin/bash
EMAIL=$1
TOPIC=$(terraform output sns_topic)

aws sns subscribe --topic-arn $TOPIC --protocol email --notification-endpoint $EMAIL
