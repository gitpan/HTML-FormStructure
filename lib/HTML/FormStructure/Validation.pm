package HTML::FormStructure::Validation;

use strict;
use base qw(Exporter);
use vars qw(@EXPORT);
@EXPORT = qw(validate error_messages);
use constant SUCCESS => '1';
use constant FAIL    => '0';

sub validate {
    my $self = shift;
    $self->query_combine;
    for my $query ($self->have('more')) {
	my $reason;
	if ($query->more eq '1') {
	    $reason = $query->name . '_fail_needed';
	}
	else {
	    $reason = $query->name . '_fail_min_size';
	}
	$query->store_error($reason)
	    if length $self->r->param($query->name) < $query->more;
    }
    return FAIL if $self->have('error');
    for my $query ($self->have('less')) {
	my $reason = $query->name . '_fail_max_size';
	$self->store_error($reason)
	    if length $self->r->param($query->name) > $query->less;
    }
    return FAIL if $self->have('error');
    for my $query ($self->have('be')) {
	for my $meth ($query->array_of('be')) {
	    next unless defined $self->r->param($query->name);
	    if (ref $meth eq 'CODE') {
		my $reason = $query->name . '__fail__' .
		    $meth->($self->r->param($query->name));
		$query->store_error($reason) unless $meth->($self->r->param($query->name));
	    }
	    else {
		my $reason = $query->name . '_fail_' . $meth;
		my $pkg    = caller(0);
		$query->store_error($reason) unless $pkg->$meth($self->r->param($query->name));
	    }
	}
    }
    return FAIL if $self->have('error');
    return SUCCESS;
}

sub error_messages {
    my $self = shift;
    my @messages;
    for my $query ($self->have('error')) {
	push @messages, @{$query->error};
    }
    return @messages;
}


1;

__END__

=head1 NAME

  $Id: Validation.pm,v 1.5 2003/10/09 11:16:41 toona Exp $

=head1 DESCRIPTION

=item

=cut
