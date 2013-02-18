#!/usr/bin/perl
while(<>){
    $_ =~ /PHY 0x([[:xdigits:]]+) \(len=[0-9]*, pl=0\): 0x([[:xdigits:]]+)/;
    $name = $1;
    $value = $2;
    print $name, $value
}
