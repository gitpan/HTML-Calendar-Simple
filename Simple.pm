package HTML::Calendar::Simple; 
$HTML::Calendar::Simple::VERSION = "0.02";

=pod

=head1 NAME

HTML::Calendar::Simple - A simple html calendar

=head1 SYNOPSIS

  use HTML::Calendar::Simple;

  my $cal = HTML::Calendar::Simple->new; # This month, this year
     $cal = HTML::Calendar::Simple->new({ 'month' => $month }); # This year
     $cal = HTML::Calendar::Simple->new({ 'month' => $month, 
                                          'year'  => $year});

  print $cal; # stringifies to something like the output of cal
  print $cal->html;

  $cal->daily_info({ 'day'      => $day,
                     'day_link' => $location,
                     $type1     => $info1,
                     $type2     => $info2,
                     'link'     => [$link, $tag],
  });

=head1 DESCRIPTION

This is a simple module which will make an HTML representation of a 
given month. You can add links to individual days, or in fact, any 
sort of information you want.

Yes, the inspiration for this came out of me looking at 
HTML::CalendarMonthSimple, and thinking 'Hmmm. A bit too complicated
for what I want. I know, I will write a simplified version.' So I did. 

=cut

use strict;
use Date::Simple;
use CGI;

use overload 
  '""' => '_stringify';

my %days   = ( 'Sun' => 0, 'Mon' => 1, 
               'Tue' => 2, 'Wed' => 3, 
               'Thu' => 4, 'Fri' => 5, 
               'Sat' => 6 );

my %months = (  1 => 'Jan', 2  => 'Feb', 3  => 'Mar',
                4 => 'Apr', 5  => 'May', 6  => 'Jun',
                7 => 'Jul', 8  => 'Aug', 9  => 'Sep',
               10 => 'Oct', 11 => 'Nov', 12 => 'Dec' );

=head2 new

  my $cal = HTML::Calendar::Simple->new;
  my $cal = HTML::Calendar::Simple->new({ 'month' => $month });
  my $cal = HTML::Calendar::Simple->new({ 'month' => $month, 
                                          'year'  => $year });

This will make a new HTML::Calendar::Simple object.

=cut

sub new {
  my $self = {};
  bless $self, shift;
  $self->_init(@_);
  return $self;
}

sub _init {
  my $self = shift;
  # validate the args passed to new, if there were any.
  my $valid_day = Date::Simple->new;
  my $ref = shift;
  if (defined $ref && ref $ref eq 'HASH') {
    my $month = exists $ref->{month} ? $ref->{month} : $valid_day->month;
    my $year  = exists $ref->{year}  ? $ref->{year}  : $valid_day->year; 
    $valid_day = $self->_date_obj($year, $month, 1);
    $valid_day = defined $valid_day ? $valid_day : Date::Simple->new;
  }
  $self->{month} = $valid_day->month;
  $self->{year}  = $valid_day->year;
  $self->{the_month} = $self->_days_list($self->{month}, $self->{year});
  $self;
}

sub spacer    { return ""               } # the filler for the first few entries
sub month     { $_[0]->{month}          } # month in numerical format
sub year      { $_[0]->{year}           } # year in YYYY form
sub the_month { @{ $_[0]->{the_month} } } # this is the list of hashrefs.

sub _cgi {
  my $self = shift;
  unless (exists $self->{cgi}) { $self->{cgi} = CGI->new; }
  return $self->{cgi};
}

=head2 daily_info

  $cal->daily_info({ 'day'      => $day,
                     'day_link' => $location, # puts an href on the day
                     $type1     => $info1,
                     $type2     => $info2,
                     'link'     => [$link, $tag],
  });

This will record that fact that $info of $type happen(s|ed) on $day.

Now, if there is no method defined to cope with $type, then the information
pased as $info will just be text printed in the cell of $day. So, if you want
something special to happen to (say) a type of 'meeting', you would have to 
define a method called _meeting.

For example: 
  
  $cal->daily_info({ 'day'     => 12, 
                     'meeting' => 'Meet swm');

and somewhere else in this module...

  sub _meeting {
    my $self = shift;
    return $self->_cgi->h1( shift );
  }

So any day that had a meeting key in its hash would be displayed as 
an <h1>$info</h1>

Note: If you call daily_info again with the same day with the same type
      BUT with different info, then the old info will get clobbered.

There is already one method in here, and that is _link. So, you can do:

  $cal->daily_info({ 'day'  => $day,
                     'link' => [$link, $tag],
  });

Note that the key 'link' takes an array ref.

Also, if you don't pass valid uris as values of the keys 'link' and
'day_link', well, that is your out if they don't work!

=cut

sub daily_info {
  my $self = shift;
  my $ref  = shift or return;
  ref $ref eq 'HASH' or return;
  my $day  = $self->_date_obj($self->year, $self->month, $ref->{'day'})
    or return;
  my %info = %{ $ref };
  delete $info{'day'};
  foreach my $day_ref ($self->the_month) {
    next unless $day_ref && $day_ref->{date} == $day;
    $day_ref->{$_} = $info{$_} foreach keys %info;
    last;
  }
}

# Glerg. Make each cell in the calendar table a table of its own. And each row
# of this table will contain a little snippet of information.

sub _row_elem {
  my $self = shift;
  my $ref  = shift or return $self->spacer;
  return $ref if $ref eq $self->spacer;
  my $q = $self->_cgi;
  my $day = exists $ref->{day_link} 
          ? $q->a({ -href => $ref->{day_link} }, $ref->{date}->day)
          : $ref->{date}->day;
  my $elem = $q->start_table . $q->Tr($q->td($day));
  my %info = %{ $ref };
  foreach my $key (keys %info) {
    next if ($key eq 'date' or $key eq 'day_link');
    my $method = "_$key";
    $elem .= $self->can($method) 
           ? $q->Tr($q->td($self->$method($info{$key})))
           : $q->Tr($q->td($info{$key}));
  }
  $elem .= $q->end_table;
  return $elem;
}

sub _link {
  my $self = shift;
  my $ref  = shift or return;
  ref $ref eq 'ARRAY' or return;
  my ($link, $tag) = @$ref;
  return $self->_cgi->a({ -href => $link }, $tag);
}

sub _table_row {
  my $self = shift;
  my @week = @_; my @row;
  push @row, $self->_row_elem($_) foreach @week;
  return @row;
}

=head2 html

  my $html = $cal->html;

This will return an html string of the calendar month in question.

=cut

sub html {
  my $self = shift;
  my @seq  = $self->the_month;
  my $q    = $self->_cgi;
  my $cal  = $q->h3($months{$self->month} . " " . $self->year)
           . $q->start_table({-border => 1}) 
           . $q->th([sort { $days{$a} <=> $days{$b} } keys %days]);
  while (@seq) {
    my @week_row = $self->_table_row(splice @seq, 0, 7);
    $cal .= $q->Tr($q->td([@week_row]));
  }
  $cal .= $q->end_table;
  return $cal;
}

sub _date_obj { Date::Simple->new($_[1], $_[2], $_[3]) }

# here is the format of what is returned from this call. Let us say a list of 
# hashrefs, so that I can tag lots of things in with it. Ick, I know, but this
# is just a messing-about at the mo. And a hashref, mmmm, makes me think of 
# an object is needed here. A Day object if I thieved an idea from somewhere else.

sub _days_list {
  my $self = shift;
  # Fill in a Date::Simple object for every day, Why not Date::Range object? 
  # Because I haven't installed it yet, and not sure it would be appropriate
  # for the way I have set this up.
  my ($month, $year) = @_;
  my $start = $self->_date_obj($year, $month, 1);
  my $end   = $start + 31;
     $end   = $self->_date_obj($end->year, $end->month, 1);
  my @seq   = map $self->spacer, (1 .. $days{$start->format("%a")});
  push @seq, { 'date' => $start++ } while ($start < $end);
  return \@seq;
}

sub _stringify {
  my $self   = shift;
  my @month  = $self->the_month;
  my $string =  "\t\t\t" . $months{ $self->month } . " " . $self->year . "\n\n";
     $string .= join "\t", sort { $days{$a} <=> $days{$b} } keys %days;
     $string .= "\n";
  while (@month) {
    $string .= join "\t", map { $_  eq $self->spacer ? "" : $_->{date}->day } 
                          splice @month, 0, 7;
    $string .= "\n";
  }
  return $string;
}

=head1 BUGS

None known

=head2 TODO

Oh....lots of things.

  o Allow for the setting of borders etc like HTML::CalendarMonthSimple.
  o Format the output better if there is info in a daily cell.
  o Perhaps overload '.' so you could add two calendars. Not sure.
  o Check the links passed in are of format http://www.stray-toaster.co.uk
    or something.
  o Get rid of the days and months hashes and replace with something better.
  o And if all that happens, it may as well be HTML::CalendarMonthSimple!!

=head1 SHOWING YOUR APPRECIATION

There was a thread on london.pm mailing list about working in a vacumn
- that it was a bit depressing to keep writing modules but never get
any feedback. So, if you use and like this module then please send me
an email and make my day.

All it takes is a few little bytes.

(Leon wrote that, not me!)

=head1 AUTHOR

Stray Toaster E<lt>F<coder@stray-toaster.co.uk>E<gt>

=head2 With Thanks

To swm E<lt>F<swm@swmcc.com>E<gt> for some roadtesting!

=head1 COPYRIGHT

Copyright (C) 2002, mwk

This module is free software; you can redistribute it or modify it
under the same terms as Perl itself.

=cut

return qw/Now beat it you bother me/;
