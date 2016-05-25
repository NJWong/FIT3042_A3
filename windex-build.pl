#!/usr/bin/perl

use 5.18.0;

use strict;
use warnings;

# Imports
use Cwd;
use LWP::UserAgent;
use Time::HiRes "usleep";
# use LWP::Protocol;
use HTTP::Response;
use HTML::TreeBuilder 5 -weak;

# ---- Global Variables ---- #

# Function prototypes
use subs qw( main set_options show_options build_link_array index_page parse_html );

# Variables for mandatory arguments
my ( $name, $starturl, $excludefile );

# Variables for optional argments
my ( $dir, $maxdepth );

# Current working directory
my $cwd = getcwd;

# List of 100 most common words that we won't index
# Taken from https://en.wikipedia.org/wiki/Most_common_words_in_English
# TODO move this to an exclude file
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

# Array to store links of interest
my @links_to_visit;
my @links_in_next_layer;

# Array to store visited pages
my @visited_pages;

# Maps a given word to an array of links that contain that word
my %word_index;

my $num_page_visits = 0;

# ---- Start the script ---- #
main;

# Main function
sub main {
    set_options;
    show_options;

    # Initiate
    push @links_in_next_layer, $starturl;

    my $depth = 0;

    while ($depth <= 1) {

        say "------ Depth: $depth ------";

        # Copy over the links for the next depth
        @links_to_visit = @links_in_next_layer;

        @links_in_next_layer = ();

        # Index each page and build the links for the next layer
        foreach my $link (@links_to_visit) {

            @visited_pages = ();

            unless ($link ~~ @visited_pages) {
                index_page $link;
                usleep(200);

                build_link_array $link;

                push @visited_pages, $link;

                if ($num_page_visits >= 1000) {
                    last;
                }

                usleep(200);
            }
        }

        $depth += 1;
    }

    # Write the index to the output file

    my $index_filename = $dir . $name;
    open(my $filehandler, '>', $index_filename) or die "Could not open the file $index_filename\n";

    foreach my $key (sort keys %word_index) {
        my @a = @{$word_index{$key}};
        print $filehandler $key;

        foreach (@a) {
            print $filehandler ",";
            print $filehandler $_;
        }

        print $filehandler "\n";
    }

    close($filehandler);

    # Print out the index
    # foreach my $key (keys %word_index) {
    #     my @a = @{$word_index{$key}};
    #     say $key;
    #     say foreach @a;
    # }

}

sub build_link_array {
    my $current_url = $_[0];
    my $user_agent = LWP::UserAgent->new();
    my $current_page = $user_agent->get($current_url);

    die "Couldn't get $current_url" unless defined $current_page;

    # Add the current page to the visited links
    push @visited_pages, $current_page;

    my $page_content = $current_page->content;

    # Create the HTML tree
    my $tree = HTML::TreeBuilder->new();
    $tree->parse($page_content);

    # Make the tree strictly an HTML::Element type
    $tree->elementify;

    # Get the main article content
    my $e = $tree->look_down("id", "mw-content-text");

    # Get all the links
    my @link_array = @{$e->extract_links('a')};    

    # Filter the links we are interested in and store them
    foreach (@link_array) {
        my($link, $element, $attr, $tag) = @$_;
        unless ($wikipedia_base_url . $link ~~ @links_in_next_layer || $link !~ /^\/wiki\/.+/g || $link =~ /^\/wiki\/\w+:/) {
            push @links_in_next_layer, $wikipedia_base_url . $link;
            $num_page_visits += 1;
        }

        if ($num_page_visits >= 1000) {
            last;
        }
    }

    say "Number of page visits: $num_page_visits";
}

# ---- Page Indexing ---- #

sub index_page {
    my $current_url = $_[0];
    my $user_agent = LWP::UserAgent->new();
    my $current_page = $user_agent->get($current_url);

    die "Couldn't get $current_url" unless defined $current_page;

    # Add the current page to the visited links
    push @visited_pages, $current_page;

    my $page_content = $current_page->content;

    # Create the HTML tree
    my $tree = HTML::TreeBuilder->new();
    $tree->parse($page_content);

    # Make the tree strictly an HTML::Element type
    $tree->elementify;

    # Get the main article content
    my $e = $tree->look_down("id", "mw-content-text");

    # Get all the links
    # my @link_array = @{$e->extract_links('a')};

    # Filter the links we are interested in and store them
    # foreach (@link_array) {
    #     my($link, $element, $attr, $tag) = @$_;
    #     push @links_to_visit, $link unless $link ~~ @links_to_visit || $link !~ /^\/wiki\/.+/g || $link =~ /^\/wiki\/\w+:/;
    # }

    # Collect all elements and store them in a hash where:
    #   key = tag
    #   value = reference to array of elements with that tag
    my %all_tags = %{$e->tagname_map};

    # Get all the paragraphs
    my @p_tags = @{$all_tags{"p"}};

    foreach (@p_tags) {
        my $para = $_->as_text;
        foreach my $word ($para =~ /\w+/g) {
            $word = lc $word;

            unless ($word ~~ @word_blacklist) {
                if (exists $word_index{$word}) {
                    # Add the current url to the array of links, unless it's already there
                    push @{$word_index{$word}}, $current_url unless $current_url ~~ @{$word_index{$word}};
                } else {
                    # Create a new hash entry and add the current url to the array
                    @{$word_index{$word}} = ($current_url);
                }
            }
        }
    }
}




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