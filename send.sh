#!/bin/bash
TIME=$(date +%s000)

aws logs create-log-stream --log-group-name sample_error_log_source --log-stream-name $TIME
aws logs put-log-events --log-group-name sample_error_log_source --log-stream-name $TIME --log-events "timestamp=$TIME,message=ERROR hello world" 
