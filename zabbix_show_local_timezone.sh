#!/bin/bash
timedatectl | grep -oP "(Time zone: \K.*$)"
