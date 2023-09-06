package Aion::View;
# ООП вроде Moose - так же добавляет 
use 5.008001;
use strict;
use warnings;

our $VERSION = "0.01";

use Aion::Carp;

# Импорт
sub import {
	my $pkg = caller;

	eval "package $pkg;
use Aion;

with qw/Aion::View::View Aion::View::Sige Aion::View::Run/;

1" or die;


}

1;