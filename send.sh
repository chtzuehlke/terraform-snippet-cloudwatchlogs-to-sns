#!/bin/bash
TOKEN=49600934446419631384148051040416195066744497575240472242
TIME=$(date +%s000)
aws logs put-log-events --log-group-name /aws/lambda/testsource --log-stream-name foo --log-events "timestamp=$TIME,message=hello world" --sequence-token $TOKEN

