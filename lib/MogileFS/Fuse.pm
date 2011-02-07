package MogileFS::Fuse;

use strict;
use utf8;
use base qw{Exporter};
use threads;
use threads::shared;

use Fuse 0.09_4;
use MogileFS::Client;
use Params::Validate qw{validate ARRAYREF SCALAR};
use POSIX qw{EEXIST EIO ENOENT EOPNOTSUPP};

#log levels
use constant ERROR => 0;
use constant DEBUG => 1;

our @EXPORT_OK = qw{
	ERROR
	DEBUG
};
our %EXPORT_TAGS = (
	LEVELS => [qw{
		ERROR
		DEBUG
	}],
);

##Private static variables

#variables to track the currently mounted Fuse object
my $instance :shared = 1;
my %unshared;

##Static Methods

#constructor
#	class      => the class to store files as in MogileFS
#	domain     => the domain to use in MogileFS
#	loglevel   => the log level to use for output
#	mountpoint => where to mount the filesystem
#	trackers   => the addresses for the MogileFS trackers
sub new {
	#create the new MogileFS::Fuse object
	my $self = shift;
	$self = shared_clone(bless({}, ref($self) || $self));

	#initialize and return the new object
	return $self->_init(@_);
}

##Instance Methods

#method that will initialize the MogileFS::Fuse object
sub _init {
	my $self = shift;
	my %opt = validate(@_, {
		'class'      => {'type' => SCALAR, 'default' => undef},
		'domain'     => {'type' => SCALAR},
		'loglevel'   => {'type' => SCALAR, 'default' => ERROR},
		'mountpoint' => {'type' => SCALAR},
		'trackers'   => {'type' => ARRAYREF},
	});

	#die horribly if we are trying to reinit an existing object
	die 'You are trying to reinitialize an existing MogileFS::Fuse object, this could introduce race conditions and is unsupported' if($self->{'id'});

	#set the instance id
	{
		lock($instance);
		$self->{'id'} = $instance;
		$instance++;
	}

	#process the MogileFS config
	$self->{'config'} = shared_clone({
		'loglevel'   => $opt{'loglevel'},
		'mountpoint' => $opt{'mountpoint'},
		'class'      => $opt{'class'},
		'domain'     => $opt{'domain'},
		'trackers'   => $opt{'trackers'},
	});

	#return the initialized object
	return $self;
}

#method that will access unshared object elements
sub _localElem {
	my $self = ($unshared{shift->id} ||= {});
	my $elem = shift;
	my $old = $self->{$elem};
	$self->{$elem} = $_[0] if(@_);
	return $old;
}

#method that will return a MogileFS object
sub client {
	my $client = $_[0]->_localElem('client');

	#create and store a new client if one doesn't exist already
	if(!defined $client) {
		my $config = $_[0]->{'config'};
		$client = MogileFS::Client->new(
			'hosts'  => [@{$config->{'trackers'}}],
			'domain' => $config->{'domain'},
		);
		$_[0]->_localElem('client', $client);
	}

	#return the MogileFS client
	return $client;
}

#return the instance id for this object
sub id {
	return $_[0]->{'id'};
}

#function that will output a log message
sub log {
	my $self = shift;
	my ($level, $msg) = @_;
	return if($level > $self->{'config'}->{'loglevel'});
	print STDERR $msg, "\n";
}

#Method to mount the specified MogileFS domain to the filesystem
sub mount {
	my $self = shift;

	#short-circuit if this MogileFS file system is currently mounted
	{
		lock($self);
		return if($self->{'mounted'});
		$self->{'mounted'} = 1;
	}

	#mount the MogileFS file system
	Fuse::main(
		'mountpoint' => $self->{'config'}->{'mountpoint'},
		'threaded' => 1,

		#callback functions
		'getattr'     => sub {
			$self->log(DEBUG, "e_getattr: $_[0]");
			$self->e_getattr(@_);
		},
		'getdir'      => sub {
			$self->log(DEBUG, "e_getdir: $_[0]");
			$self->e_getdir(@_);
		},
		'getxattr'    => sub {
			$self->log(DEBUG, "e_getxattr: $_[0]: $_[1]");
			$self->e_getxattr(@_);
		},
		'link'        => sub {
			$self->log(DEBUG, "e_link: $_[0] $_[1]");
			$self->e_link(@_);
		},
		'listxattr'   => sub {
			$self->log(DEBUG, "e_listxattr: $_[0]");
			$self->e_listxattr(@_);
		},
		'mknod'       => sub {
			$self->log(DEBUG, "e_mknod: $_[0]");
			$self->e_mknod(@_);
		},
		'open'        => __PACKAGE__ . '::e_open',
		'readlink'    => sub {
			$self->log(DEBUG, "e_readlink: $_[0]");
			$self->e_readlink(@_);
		},
		'removexattr' => sub {
			$self->log(DEBUG, "e_removexattr: $_[0]: $_[1]");
			$self->e_removexattr(@_);
		},
		'rename'      => sub {
			$self->log(DEBUG, "e_rename: $_[0] -> $_[1]");
			$self->e_rename(@_);
		},
		'setxattr'    => sub {
			$self->log(DEBUG, "e_setxattr: $_[0]: $_[1] => $_[2]");
			$self->e_setxattr(@_);
		},
		'statfs'      => sub {
			$self->log(DEBUG, 'e_statfs');
			$self->e_statfs(@_);
		},
		'symlink'     => sub {
			$self->log(DEBUG, "e_symlink: $_[0] $_[1]");
			$self->e_symlink(@_);
		},
		'unlink'      => sub {
			$self->log(DEBUG, "e_unlink: $_[0]");
			$self->e_unlink(@_);
		},
	);

	#reset mounted state
	{
		lock($self);
		$self->{'mounted'} = 0;
	}

	#return
	return;
}

sub sanitize_path {
	my $self = shift;
	my ($path) = @_;

	# Make sure we start everything from '/'
	$path = '/' unless(length($path));
	$path = '/' if($path eq '.');
	$path = '/' . $path unless($path =~ m!^/!so);

	return $path;
}

##Callback Functions

sub e_getattr {
	return -EOPNOTSUPP();
}

sub e_getdir {
	return -EOPNOTSUPP();
}

sub e_getxattr {
	return -EOPNOTSUPP();
}

sub e_link {
	return -EOPNOTSUPP();
}

sub e_listxattr {
	return -EOPNOTSUPP();
}

sub e_mknod {
	my $self = shift;
	my ($path) = @_;
	$path = $self->sanitize_path($path);

	#attempt creating an empty file
	my $mogc = $self->client();
	my ($errcode, $errstr) = (-1, '');
	my $response = eval {$mogc->new_file($path, $self->{'config'}->{'class'})->close};
	if($@ || !$response) {
		#set the error code and string if we have a MogileFS::Client object
		if($mogc) {
			$errcode = $mogc->errcode || -1;
			$errstr = $mogc->errstr || '';
		}
		$self->log(ERROR, "Error creating file: $errcode: $errstr");
		$! = $errstr;
		$? = $errcode;
		return -EIO();
	}

	#return success
	return 0;
}

sub e_readlink {
	return 0;
}

sub e_removexattr {
	return -EOPNOTSUPP();
}

sub e_rename {
	return -EOPNOTSUPP();
}

sub e_setxattr {
	return -EOPNOTSUPP();
}

sub e_statfs {
	return 255, 1, 1, 1, 1, 1024;
}

sub e_symlink {
	return -EOPNOTSUPP();
}

sub e_unlink {
	my $self = shift;
	my ($path) = @_;
	$path = $self->sanitize_path($path);

	#attempt deleting the specified file
	my $mogc = $self->client();
	my ($errcode, $errstr) = (-1, '');
	eval {$mogc->delete($path)};
	if($@) {
		#set the error code and string if we have a MogileFS::Client object
		if($mogc) {
			$errcode = $mogc->errcode || -1;
			$errstr = $mogc->errstr || '';
		}
		$self->log(ERROR, "Error unlinking file: $errcode: $errstr");
		$! = $errstr;
		$? = $errcode;
		return -EIO();
	}

	#return success
	return 0;
}

1;
