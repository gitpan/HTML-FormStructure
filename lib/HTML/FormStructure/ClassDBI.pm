package HTML::FormStructure::ClassDBI;
use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use constant THBAR => '__';
use vars qw(@EXPORT);
@EXPORT = qw(fillin_resource get_table_rec table_handler
	     insert_record update_record
	     gen_table_name gen_column_name
	     gen_related_table_name gen_data_class);

sub fillin_resource {
    my $self = shift;
    my $ret  = shift || {};
    my $recs = $self->get_table_rec;
    for my $table (keys %{$recs}) {
	my $rec = $recs->{$table}->attributes_hashref;
	for my $query ($self->search_like(name => THBAR)) {
	    my $tbl  = $self->gen_table_name($query->name);
	    my $col = $self->gen_column_name($query->name);
	    $ret->{$query->name} = $rec->{$col} if defined $rec->{$col};
	}
    }
    return $ret;
}

sub get_table_rec {
    my $self = shift;
    my ($tables,$ret) = ({},{});
    my $pkg = caller(0);
    $ret = $pkg->my_record if $pkg->can('my_record'); # table_name => $obj
    return $ret if keys %{$ret};
    for my $query ($self->search_like(name => THBAR)) {
	my $table   = $self->gen_table_name($query->name);
	my $r_table = $self->gen_related_table_name($query->name);
	my $column  = $self->gen_column_name($query->name);
	if ($r_table) {
	    $tables->{$r_table}->{related}->{$table} =
		$self->gen_data_class($table);
	}
	else {
	    $tables->{$table}->{static} =
		$self->gen_data_class($table);
	}
    }
    for my $key (keys %{$tables}) {
	if ($tables->{$key}->{static}) {
	    my $id = $self->r->param(sprintf "%s_id", $key)
		|| $self->r->param('id');
	    my $class = $tables->{$key}->{static};
	    $ret->{$key} = $class->retrieve($id);
	    delete $ret->{$key} unless $ret->{$key};
	}
	if ($tables->{$key}->{related}) {
	    my $id = $ret->{$key}->id;
	    my $id_name = sprintf "%s_id",$key;
	    for (keys %{$tables->{$key}->{related}}) {
		my $class = $tables->{$key}->{related}->{$_};
		$ret->{$_} = $class->search($id_name => $id)->first;
		delete $ret->{$key} unless $ret->{$key};
	    }
	}
    }
    return $ret;
}

sub table_handler_mode {
    my $self = shift;
    my $mode = shift;
    $self->{table_handler_mode} = $mode if $mode;
    $self->{table_handler_mode};
}

sub table_handler {
    my $self    = shift;
    my $new_rec = shift || {};
    my $return = {};
    if ($self->table_hanlder_mode eq 'update') {
	$return = $self->update_record($return);
    }
    else {
	$return = $self->insert_record($return,$new_rec);
    }
    return $return;
}

sub update_record {
    my $self    = shift;
    my $return = shift;
    my $tables = $self->tables;
    for my $tablename (keys %{$tables}) {
	my $rec = $tables->{$tablename};
	for my $query ($self->have('column')) {
	    my $col = $self->gen_column_name($query->name);
	    my $tbl = $self->gen_table_name($query->name);
	    next if $tbl ne $tablename;
	    $rec->$col($query->store);
	}
	$rec->update;
	$return->{$tablename} = $rec;
    }
    return $return;
}

sub insert_record {
    my $self = shift;
    my $return  = shift;
    my $new_rec = shift;
    for my $query ($self->have('column')) {
	my $column  = $self->gen_column_name($query->name);
	my $table   = $self->gen_table_name($query->name);
	my $r_table = $self->gen_related_table_name($query->name);
	if ($r_table) {
	    $new_rec->{$r_table}->{related}->{$table}->{$column} =
		$query->store;
	} else {
	    $new_rec->{$table}->{static}->{$column} =
		$query->store;
	}
    }
    for my $table (keys %{$new_rec}) {
	if ($new_rec->{$table}->{static}) {
	    my $class = $self->gen_data_class($table);
	    $new_rec->{$table}->{static}->{createstamp} =
		Time::Piece->new(time)->datetime;
	    $new_rec->{$table}->{static} =
		$class->create($new_rec->{$table}->{static});
	    $return->{$table} = $new_rec->{$table}->{static};
	}
    }
    for my $table (keys %{$new_rec}) {
	for my $child_table (keys %{$new_rec->{$table}->{related}}) {
	    my $class  = $self->gen_data_class($child_table);
	    my $target = $new_rec->{$table}->{related}->{$child_table};
	    my $related_key = sprintf "%s_id", $table;
	    if (exists $target->{$related_key}) {
		$target->{$related_key} = $new_rec->{$table}->{static}->id;
	    }
	    $return->{$table} = $class->create($target);
	}
    }
    return $return;
}


sub gen_table_name {
    my $self = shift;
    return (split THBAR, shift)[0];
}

sub gen_column_name {
    my $self = shift;
    return (split THBAR, shift)[1];
}

sub gen_related_table_name {
    my $self = shift;
    return (split THBAR, shift)[2];
}

sub gen_data_class {
    my $self = shift;
    my $tbl  = shift;
    my ($one,$two) = split "_", $tbl;
    my $pkg = (caller)[0];
    my $class;
    if ($pkg->can('data_class')) {
	$class = $pkg->data_class; 
    }
    else {
	$class = sprintf "%s::%s", $pkg->base_data_class,(ucfirst $one . ucfirst $two);
    }
    eval { require "${class}.pm";
	   import $class; };
    return $class;
}


1;

__END__

=head1 NAME

  $Id: ClassDBI.pm,v 1.3 2003/10/09 10:42:37 toona Exp $

=head1 DESCRIPTION

=item

=cut
