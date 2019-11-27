#!/bin/bash
LOG_GROUP=$(terraform output log_group)
TIME=$(date +%s000)

aws logs create-log-stream --log-group-name $LOG_GROUP --log-stream-name $TIME
TOKEN=$(aws logs put-log-events --log-group-name $LOG_GROUP --log-stream-name $TIME --log-events "timestamp=$TIME,message=INFO a info message" --query nextSequenceToken --output text)
aws logs put-log-events --log-group-name $LOG_GROUP --log-stream-name $TIME --log-events "timestamp=$TIME,message=ERROR an error message" --sequence-token $TOKEN
