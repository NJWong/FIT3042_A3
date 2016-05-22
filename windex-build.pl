#!/usr/bin/perl

use 5.18.0;

use strict;
use warnings;

# Imports
use Cwd;
use LWP::UserAgent;
# use LWP::Protocol;
use HTTP::Response;
use HTML::TreeBuilder;

# Function definitions
use subs qw( main set_options show_options get_page_content );

# Variables for mandatory arguments
my ( $name, $starturl, $excludefile );

# Variables for optional argments
my ( $dir, $maxdepth );

# Current working directory
my $cwd = getcwd;

# Main function
sub main {
    set_options;
    show_options;
    get_page_content;
}

# ---- Start the script ---- #
main;

# ---- Function definitions ---- #

sub set_options {

    # Check number of arguments - between 3 and 5 (inclusive)
    die "Error - Number of args: " . scalar @ARGV . ". Expected 3-5.\n" unless @ARGV >= 3 && @ARGV <= 5;

    # Assign mandatory variables
    ( $name, $starturl, $excludefile ) = ( @ARGV );

    # ---- Handle mandatory arguments ---- #

    # Arg1 string must contain at least one word character
    die "Error - Invalid arg1: \"" . scalar $ARGV[0] . "\". Index filename not specified" unless $ARGV[0] =~ /\w+/;

    # Arg2 string must not be empty
    die "Error - Invalid arg2: \"" . scalar $ARGV[1] . "\". Invalid Start URL" unless $ARGV[1] =~ /.+\.wikipedia\.org\/.*/;

    # Arg3 string must point to an existing plain file
    die "Error - Invalid arg3: \"" . scalar $ARGV[2] . "\". File does not exist" unless -f $cwd . "/" . scalar $ARGV[2];

    # ---- Handle optional arguments ---- #

    # Arg 4 specifies either maxdepth or the index directory
    if (@ARGV >= 4) {
        if ($ARGV[3] =~ /^maxdepth=\d$/) {

            my @split = split(/=/, $ARGV[3]);
            my $value = int $split[1];

            if ($value >= 0 and $value <= 5) {
                $maxdepth = $value;
            }
        } elsif ($ARGV[3] =~ /^dir=\w+/) {

            my @split = split(/=/, $ARGV[3]);
            my $value = $split[1];

            if (-d $cwd . "/" . $value) {
                $dir = $cwd . "/" . $value . "/";
            }
        }
    }

    # If two optional arguments are specified
    if (@ARGV == 5) {
        if ($ARGV[4] =~ /^maxdepth=\d$/) {

            my @split = split(/=/, $ARGV[4]);
            my $value = int $split[1];

            if ($value >= 0 and $value <= 5) {
                $maxdepth = $value;
            }
        } elsif ($ARGV[4] =~ /^dir=\w+/) {

            my @split = split(/=/, $ARGV[4]);
            my $value = $split[1];

            if (-d $cwd . "/" . $value) {
                $dir = $cwd . "/" . $value . "/";
            }
        }
    }

    # Set default values for the optional parameters if they are not defined
    $dir = $cwd . "/" unless defined $dir;
    $maxdepth = 3 unless defined $maxdepth;
}

sub show_options {
    say "\nRunning script with the following options:";
    say "\tIndex name: " . $name;
    say "\tStart URL: " . $starturl;
    say "\tExclude File: " . $excludefile;
    say "\tMax Depth: " . $maxdepth;
    say "\tDirectory: " . $dir;
}

sub get_page_content {
    my $url = $starturl;
    my $user_agent = LWP::UserAgent->new();
    my $res = $user_agent->get($url);

    die "Couldn't get $url" unless defined $res;

    print $res->content;
}
