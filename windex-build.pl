#!/usr/bin/perl

use 5.18.0;

use strict;
use warnings;

# Imports
use Cwd;
use Time::HiRes "usleep";
use LWP::UserAgent;
use HTML::TreeBuilder 5 -weak;

# ---- Global Variables ---- #

# Function prototypes
use subs qw( main set_options show_options load_exception_file index_page write_index_to_file );

# Variables for mandatory arguments
my ( $name, $starturl, $excludefile );

# Variables for optional argments
my ( $dir, $maxdepth );

# Current working directory
my $cwd = getcwd;

# List of 100 most common words that we won't index
# Taken from https://en.wikipedia.org/wiki/Most_common_words_in_English
my @word_blacklist;

# Making it easier on us by only considering english pages
my $wikipedia_base_url = "https://en.wikipedia.org";

# Store links to visit immediately
my @links_to_visit;

# Store links to visit one step (AKA, depth, layer, etc.) down
my @links_in_next_layer;

# Array to store visited pages
my @visited_pages;

# Maps a given word to an array of links that contain that word
my %word_index;

my $total_links_found = 0;
my $num_page_visits = 0;
my $max_page_visits = 500; #TODO change this to 1000 before submission

# ---- Start the script ---- #
main;

# Main function
sub main {

    set_options;
    show_options;
    load_exception_file;

    # Initiate
    push @links_in_next_layer, $starturl;

    # Starting at layer 0 (the starting page)
    my $depth = 0;

    # Do a breadth first traversal of links
    while ($depth <= $maxdepth) {
        # Check if we have exceeded the maximum number of page visits
        if ($num_page_visits >= $max_page_visits) {
            last;
        }

        say "------ Depth: $depth ------";

        # Move down one layer
        @links_to_visit = @links_in_next_layer;

        # We want to create a new list for the next layer
        @links_in_next_layer = ();

        # Visit and index each page in the list
        while (scalar @links_to_visit > 0) {

            my $next_page_url = shift @links_to_visit;

            unless ($next_page_url ~~ @visited_pages) {
                # say $next_page_url;
                index_page $next_page_url;
                $num_page_visits += 1;
            
                usleep(200);
                say "Pages Visited: $num_page_visits";
            } else {
                say "Already visited $next_page_url";
            }
            
            if ($num_page_visits >= $max_page_visits) {
                last;
            }
        }

        # This layer has been completely traversed using BFT
        say "Completed!";
        $depth += 1;
    }

    # Output results before finishing
    write_index_to_file;
    
    say "Visited: " . scalar @visited_pages;
}

# Load the exception words
sub load_exception_file {
    open (my $fh, '<', $excludefile) or die "Could not open $excludefile";
    @word_blacklist = split(" ", <$fh>);
    close($fh);
}

# ---- Page Indexing ---- #

sub index_page {
    my $current_url = $_[0];
    my $user_agent = LWP::UserAgent->new();
    my $current_page = $user_agent->get($current_url);

    die "Couldn't get $current_url" unless defined $current_page;

    # We don't need to return to this page again
    push @visited_pages, $current_url;

    # Create a tree structure from the HTML we retrieved
    my $page_content = $current_page->content;
    my $tree = HTML::TreeBuilder->new();
    $tree->parse($page_content);

    # Make the tree strictly an HTML::Element type
    $tree->elementify;

    # Only the main article content is of interest
    my $article_content = $tree->look_down("id", "mw-content-text");

    # Don't worry about the reference list
    my $reference_list = $tree->look_down("class", "references");
    if (defined $reference_list) {
        $reference_list->detach();
    }

    # Look for all the anchor elements in the content
    my @link_array = @{$article_content->extract_links('a')};

    # Find the links of interest for the next layer (with respect to the BFT depth)
    foreach (@link_array) {
        my($link, $element, $attr, $tag) = @$_;

        # Populate the array of links with links of interest
        unless ($wikipedia_base_url . $link ~~ @visited_pages || $wikipedia_base_url . $link ~~ @links_in_next_layer || $link !~ /^\/wiki\/.+/g || $link =~ /^\/wiki\/\w+:/) {
            push @links_in_next_layer, $wikipedia_base_url . $link;
            $total_links_found += 1;
        }
    }

    # Collect all elements and store them in a hash where:
    #   key = tag
    #   value = reference to array of elements with that tag
    my %all_tags = %{$article_content->tagname_map};

    # Look for words in elements like headings, paragraphs, and list items

    my @word_elements = ();
    if (exists $all_tags{"h2"}) {
        push @word_elements, @{$all_tags{"h2"}};
    }

    if (exists $all_tags{"h3"}) {
        push @word_elements, @{$all_tags{"h3"}};
    }

    if (exists $all_tags{"h4"}) {
        push @word_elements, @{$all_tags{"h4"}};
    }

    if (exists $all_tags{"p"}) {
        push @word_elements, @{$all_tags{"p"}};
    }

    if (exists $all_tags{"li"}) {
        push @word_elements, @{$all_tags{"li"}};
    }

    foreach (@word_elements) {
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

sub write_index_to_file {
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