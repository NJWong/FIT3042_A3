#!/usr/bin/perl

use 5.18.0;

use strict;
use warnings;

# Imports
use Cwd;
use LWP::UserAgent;
# use LWP::Protocol;
use HTTP::Response;
use HTML::TreeBuilder 5 -weak;

# ---- Global Variables ---- #

# Function prototypes
use subs qw( main set_options show_options get_page_content parse_html );

# Variables for mandatory arguments
my ( $name, $starturl, $excludefile );

# Variables for optional argments
my ( $dir, $maxdepth );

# Current working directory
my $cwd = getcwd;

# List of 100 most common words that we won't index
# Taken from https://en.wikipedia.org/wiki/Most_common_words_in_English
my @word_blacklist = qw( the be to of and a in that have I it for not on with
                        he as you do at this but his by from they we say her
                        she or an will my one all would there their what so
                        up out if about who get which go me when make can like
                        time no just him know take people into year your good
                        some could them see other than then now look only come
                        its over think also back after use two how our work
                        first well way even new want because any these give
                        day most us );

my $wikipedia_base_url = "https://en.wikipedia.org";

# Main function
sub main {
    set_options;
    show_options;

    # Get the page contant
    # my $page_content = get_page_content;

    my $current_url = $starturl;
    my $user_agent = LWP::UserAgent->new();
    my $current_page = $user_agent->get($current_url);

    die "Couldn't get $current_url" unless defined $current_page;

    my $page_content = $current_page->content;

    # Create the HTML tree
    my $tree = HTML::TreeBuilder->new();
    $tree->parse($page_content);

    # Make the tree strictly an HTML::Element type
    $tree->elementify;

    # Get the main article content
    my $e = $tree->look_down("id", "mw-content-text");

    # Get all the links
    my $links = $e->extract_links('a');

    my @links_deref = @$links;

    my @link_strings;

    foreach (@links_deref) {
        my($link, $element, $attr, $tag) = @$_;
        push @link_strings, $link unless $link ~~ @link_strings || $link !~ /^\/wiki\/.+/g || $link =~ /^\/wiki\/\w+:/;
    }

    say foreach sort @link_strings;

    # Create a hash based on the tags within the main article content
    my $e_map = $e->tagname_map;

    # Dereference the hash reference
    my %e_hash = %$e_map;

    # Get all the paragraphs
    my $a = $e_hash{"p"};

    my @a_deref = @$a;

    my @word_list;

    foreach (@a_deref) {
        my $para = $_->as_text;
        foreach my $word ($para =~ /\w+/g) {
            $word = lc $word;
            push @word_list, $word unless $word ~~ @word_list || $word ~~ @word_blacklist;
        }
    }

    # foreach (sort @word_list) {
    #     print $_ . " ";
    # }





    

    # my @e_text = $e->as_text;


    # my @e_list = $e->content_list;

    # foreach (@e_list) {
    #     print $_->as_text() . "\n";
    # }

}

# ---- Start the script ---- #
main;

# ---- Page Indexing ---- #

sub get_page_content {
    my $url = $starturl;
    my $user_agent = LWP::UserAgent->new();
    my $page = $user_agent->get($url);

    die "Couldn't get $url" unless defined $page;

    return $page->content;
}

# sub parse_html(html_content) {

# }

# ---- Argument Parsing ---- #

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

# Display the options that the script is running with
sub show_options {
    say "\nRunning script with the following options:";
    say "\tIndex name: " . $name;
    say "\tStart URL: " . $starturl;
    say "\tExclude File: " . $excludefile;
    say "\tMax Depth: " . $maxdepth;
    say "\tDirectory: " . $dir;
    print "\n";
}