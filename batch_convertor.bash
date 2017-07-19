#!/bin/bash

############################
# Created by Butterfly0923 #
############################

# 2014-08-12 13:51:02
# This script is used to 

set -u

formula_list=all_sosoti.txt
concurrency=4

rm -rf x??
split -d -n r/$concurrency "$formula_list"

for f in x??; do
	{
		mkdir $f.dir
		cd $f.dir
		cp ../$f ../formulas2png.pl ../night_tex2png .
		./night_tex2png $f
	} >"$f.out" 2>"$f.log" &
done
