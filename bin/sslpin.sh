#!/bin/bash

openssl s_client -servername api.xxtou.ch -connect api.xxtou.ch:443 | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
