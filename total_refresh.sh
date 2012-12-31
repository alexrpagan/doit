#!/bin/bash

psql doit -U doit -c 'drop schema doit cascade;create schema doit;'
./init "doit -U doit"
