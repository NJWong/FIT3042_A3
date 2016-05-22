#!/usr/bin/perl

use 5.18.0;

use strict;
use warnings;

# Imports
use Cwd;
use LWP::UserAgent;
use HTML::TreeBuilder;

# Function definitions
use subs qw( main validate_arguments );

# Variables for mandatory arguments
my ( $name, $starturl, $excludefile );

# Variables for optional argments
my ( $dir, $maxdepth );

# Current working directory
my $cwd = getcwd;

# Main function
sub main {
    # say $cwd . scalar $ARGV[2];
    validate_arguments;
}

sub validate_arguments {

    # Check number of arguments - between 3 and 5 (inclusive)
    die "Error - Number of args: " . scalar @ARGV . ". Expected 3-5.\n" unless @ARGV >= 3 && @ARGV <= 5;

    # Assign variables to the passed in values
    ( $name, $starturl, $excludefile, $dir, $maxdepth ) = ( @ARGV );

    # Arg1 string must contain at least one word character
    die "Error - Invalid arg1: \"" . scalar $ARGV[0] . "\". Index filename not specified" unless $ARGV[0] =~ /\w+/;

    # Arg2 string must not be empty
    die "Error - Invalid arg2: \"" . scalar $ARGV[1] . "\". Start URL not specified" unless $ARGV[1] =~ /.+/;

    # Arg3 string must point to an existing plain file
    die "Error - Invalid arg3: \"" . scalar $ARGV[2] . "\". Excemption file does not exist" unless -f $cwd . "/" . scalar $ARGV[2];

    say $name;
    say $starturl;
    say $excludefile;

    # Check optional arguments
    $dir = 'current_dir' unless defined $dir;
    $maxdepth = 3 unless defined $maxdepth;

    say $dir;
    say $maxdepth;
}




# Start the script
main;




# my $url = 'http://www.google.com.au';
# my $user_agent = LWP::UserAgent->new();
# my $res = $user_agent->get($url);

# die "Couldn't get $url" unless defined $res;

# print $res->content;