package Aion::View;
# ООП вроде Moose - так же добавляет 
use 5.008001;
use strict;
use warnings;

our $VERSION = "0.01";

use List::Util qw//;
use Sub::Util qw//;

# Загруженные отображения
our @USE;

# use Exporter 'import';
# our @EXPORT = our @EXPORT_OK = (
	# qw/extends new create_from_params create_from_request upgrade has ATTRIBUTE/,
	# @query::EXPORT,
# );

# вызывается из другого пакета, для импорта данного
sub import {
	
	my ($pkg, $path) = caller;

	# Для меты:
	push @USE, $pkg;

	# Импорт утилит:
	for my $k (@query::EXPORT) {
		*{"${pkg}::$k"} = *{$query::{$k}}{CODE};
	}

	*{"${pkg}::extends"} = \&extends;
	*{"${pkg}::new"} = \&new;
	*{"${pkg}::create_from_params"} = \&create_from_params;
	*{"${pkg}::create_from_request"} = \&create_from_request;
	*{"${pkg}::upgrade"} = \&upgrade;
	*{"${pkg}::has"} = \&has;
	*{"${pkg}::ATTRIBUTE"} = \&ATTRIBUTE;
	%{"${pkg}::ATTRIBUTE"} = ();


	my $io = *{"${pkg}::DATA"}{IO};
	
	my ($data_html) = read_file($path) =~ m/^__DATA__\s+(.*)\z/sm;
	my $path_html = $path =~ s/\.pm$/.html/r;
	my $exists_html = -e $path_html;

	die "Одновременное использование секции __DATA__ и файла $path_html" if defined($data_html) && $exists_html;

	sige_compile $data_html, $pkg if $data_html;
	sige_compile read_file($path_html), $pkg if $exists_html;

	# Устанавливаем телеметрию:
	if($main_config::view_telemetry) {
		aroundsub $pkg => qr/^${pkg}::\w+$/a => \&_view_telemetry;		
	}
}

sub _view_telemetry {
	my $sub = shift;
	my $name = Sub::Util::subname $sub;
	my $refmark = refmark $name;
	my @x = wantarray? $sub->(@_): scalar($sub->(@_));
	undef $refmark;
	wantarray? @x: $x[0]
}

# Наследование
sub extends {
	my ($pkg, $path) = caller;

	for(@_) {  # подключаем
		eval "require $_";
		die if $@;
	}	

	@{"${pkg}::ISA"} = @_;

	my $ATTRIBUTE = $pkg->ATTRIBUTE;

	# Добавляем наследуемые атрибуты
	for(@_) {
		next if !$_->can("ATTRIBUTE");
		my $ATTRIBUTE_EXTEND = $_->ATTRIBUTE;
		while(my ($k, $v) = each %$ATTRIBUTE_EXTEND) {
			$ATTRIBUTE->{$k} = $v;
		}
	}

	return;
}

# создаёт свойство
my $IN = [qw/path query data/];
my %IN_MAP = (qw/path SLUG query GET data POST cookie COOKIE header HEADER/);
sub has(@) {
	my $property = shift;

	return exists $property->{$_[0]} if List::Util::blessed($property);
	
	my $pkg = caller;

	# атрибуты
	for my $name (ref $property? @$property: $property) {

		die "has: метод $name уже есть в $pkg" if $pkg->can($name) && !exists ${"${pkg}::ATTRIBUTE"}{$name};

		my %opt = @_;

		die "has: свойство $name имеет странный is='$opt{is}'" if $opt{is} !~ /^(ro|rw)[+-]?$/;

		for my $key (keys %opt) {
			die "has: свойство $name имеет странный атрибут '$key'" if $key !~ /^(is|isa|default|coerce|in|from|arg)$/;
		}

		$opt{name} = $name;
		$opt{ro} = $opt{is} =~ /o/? 1: 0;
		$opt{rw} = $opt{is} =~ /w/? 1: 0;
		$opt{input} = $opt{is} !~ /-/? 1: 0;
		$opt{required} = $opt{is} =~ /\+/? 1: 0;
		
		if(defined $opt{isa}) {
			#$opt{isa} = Object[$opt{isa}] unless ref $opt{isa};
			#opt{isa} = CodeRef[$opt{isa}] if CodeRef->include($opt{isa});
			
			die "has: isa у свойства $name должна быть Aion::View::Type" if !UNIVERSAL::isa($opt{isa}, 'Aion::View::Type');
		}
		
		if(defined(my $arg = $opt{arg})) {
			die "has $name: arg=`$arg` - а допускаются только параметры `-A`" unless $arg =~ /^-\w\z/a;
			
			${"${pkg}::ATTRIBUTE_RUN"}{$arg} = $name;
		}

		$opt{coerce} = $opt{isa} if $opt{coerce} == 1;

		$opt{from} = [split /\s+/, $opt{from}] if exists $opt{from};
		$opt{in} = 1 if exists $opt{from} && !exists $opt{in};

		if(exists $opt{in}) {
			my $in = $opt{in} == 1? $IN: [split /\s+/, $opt{in}];
			die "has: свойство $name имеет недопустимый in => '$opt{in}'" if !all { exists $IN_MAP{$_} } @$in;
			$opt{in} = $in;
		}

		die "has: from у свойства $name никогда не сработает, т.к. это не свойство ввода!" if exists $opt{from} && !$opt{input};
		die "has: in у свойства $name никогда не сработает, т.к. это не свойство ввода!" if exists $opt{in} && !$opt{input};

		$opt{lazy} = ref $opt{default} eq "CODE";
		$opt{is_natural_default} = exists $opt{default} && !$opt{lazy};

		die "has: default у свойства $name никогда не сработает, т.к. свойство обязательно!" if exists $opt{default} && $opt{required};
		#die "has: coerce у свойства $name никогда не сработает, т.к. свойство не имеет сеттера!" if $opt{coerce} && $opt{ro} && ;

		if($opt{lazy}) {
			Sub::Util::set_subname "${pkg}::${name}__DEFAULT__" => $opt{default};
			
			$opt{default} = wrapsub $opt{default} => \&_view_telemetry if $main_config::view_telemetry;
		}
		
		# Валидируем default, который будет устанавливаться в атрибуты
		$opt{isa}->validate($opt{default}, $name, $pkg) if $opt{is_natural_default} && $opt{isa};

		# Когда осуществлять проверки: 
		#   ro - только при выдаче
		#   wo - только при установке
		#   rw - при выдаче и учтановке
		#   no - никогда не проверять
		# my $isa_mode = $main_config::aion_view_isa_mode // "rw";
		# my @isa_mode = qw/ro wo rw no/;
		# do { local $, = ", "; die "\$main_config::aion_view_isa_mode должен быть [@isa_mode], а не $isa_mode" } unless $isa_mode ~~ \@isa_mode;

		my $coerce; my $isa;
		$coerce = "\$val = \$ATTRIBUTE{$name}{coerce}->coerce(\$val); " if $opt{coerce};
		$isa = "\$ATTRIBUTE{$name}{isa}->validate(\$val, '$name', __PACKAGE__); " if $opt{isa};
		# my $ro_isa = $isa_mode ~~ [qw/ro rw/]? $isa: "";
		# my $wo_isa = $isa_mode ~~ [qw/ro rw/]? $isa: "";

		my $set = $opt{ro}? "die 'has: $name is ro'":
			"$coerce$isa\$self->{$name} = \$val; \$self";
		my $get = join "", (
			$opt{lazy}? "if(exists \$self->{$name}) { \$val = \$self->{$name} } else {
				\$val = \$ATTRIBUTE{$name}{default}->(\$self);$coerce
				\$self->{$name} = \$val;
			}; ":
				"\$val = \$self->{$name}; "
		),
		$isa, "\$val";


		my $DEBUG = 0;
		if($DEBUG) {
			$set = "print ref \$self, '#$name ⟵ ', \"\\n\"; $set";
			$get = "my \$x=$get; print ref \$self, '#$name ⟶ ', length(\$x)<25? \$x: substr(\$x, 0, 25) . '…', \"\\n\"; \$x";
		}
		#$get = "trace '$name'; $get";

		eval "package ${pkg} {
			our %ATTRIBUTE;
			sub $name {
				my (\$self, \$val) = \@_;
				if(\@_>1) { $set } else { $get }
			}
		}";
		die if $@;

		#eval "package ${pkg} { sub has_$name { exists \$_[0]->{$name} } }";
		#die if $@;

		${"${pkg}::ATTRIBUTE"}{$name} = \%opt;
	}
	return;
}

# конструктор
sub new {
	my ($cls, %value) = @_;
	
	my ($self, @errors) = $cls->create_from_params(%value);

	die join "", "has:\n\n", map "* $_\n", @errors if @errors;

	$self
}

# Устанавливает свойства и выдаёт объект и ошибки
sub create_from_params {
	my ($cls, %value) = @_;
	
	$cls = ref $cls || $cls;
	my $self = bless {}, $cls;

	my @required;
	my @errors;

	while(my ($name, $opt) = each %{$cls->ATTRIBUTE}) {

		if(exists $value{$name}) {
			my $val = delete $value{$name};
			
			if($opt->{input}) {
				$val = $opt->{coerce}->coerce($val) if $opt->{coerce};

				push @errors, $opt->{isa}->detail($val, $name) if $opt->{isa} && !$opt->{isa}->include($val);
				$self->{$name} = $val;
			}
			else {
				push @errors, "Свойство $name нельзя устанавливать через конструктор!";
			}
		} else {
			$self->{$name} = $opt->{default} if $opt->{is_natural_default};
			push @required, $name if $opt->{required};
		}

	}

	do {local $" = ", "; unshift @errors, "Свойства @required — обязательны!"} if @required > 1;
	unshift @errors, "Свойство @required — обязательно!" if @required == 1;
	
	my @fakekeys = sort keys %value;
	unshift @errors, "@fakekeys — нет свойства!" if @fakekeys == 1;
	do {local $" = ", "; unshift @errors, "@fakekeys — нет свойств!"} if @fakekeys > 1;

	return $self, @errors;
}

# Создаёт объект с параметрами запроса
sub create_from_request {
	my ($view_class, $q) = @_;

	my %param;
	while(my ($name, $opt) = each %{$view_class->ATTRIBUTE}) {
		next if !$opt->{in};
		next if $opt->{from} && !($q->method ~~ $opt->{from});

		for my $in (@{$opt->{in}}) {
			my $in_map = $IN_MAP{$in};
			my $param = $q->$in_map;
			$param{$name} = $param->{$name}, last if exists $param->{$name};
		}
	}

	my ($self, @errors) = $view_class->create_from_params(%param);
	if(@errors) {
		die Aion::Response->bad_request(join "", map "⎆ $_\n", @errors);
	}

	$self
}

# Добавляет свойства в объект
sub upgrade {
	my ($self, %value) = @_;

	my $attr = $self->ATTRIBUTE;

	while(my ($name, $value) = each %value) {

		die "Нет атрибута $name." if !exists $attr->{$name};

		$self->$name($value);
	}

	$self
}

# Возвращает атрибуты пакета
sub ATTRIBUTE {
	my ($cls) = @_;

	$cls = ref $cls || $cls;

	\%{"${cls}::ATTRIBUTE"}
}

1;


__END__

=encoding utf-8

=head1 NAME

Aion::View — объектно-ориентированный фреймворк вроде Moose и Moo

=head1 SYNOPSIS

	use common::sense;
	
	# Пакет Calculator может складывать, вычитать, делить и умножать два числа
	package Calculator {
	    use common::sense;
	    use Aion::View;
	
	    # Внедряет атрибуты у has - in, from, конструктор new_from_request
	    with 'Aion::Role::Controller';
	
	    has a  => (is => 'ro+', isa => Num, in => 'path');
	    has op => (is => 'ro+', isa => MatchStr[qr!^[-+*/]$!], in => 'query');
	    has b  => (is => 'ro+', isa => Num, in => 'path');
	
	#@method GET /calculate/{a}/{b} „Вычисляет выражение”
	    sub get {
	        my ($self) = @_;
	        eval join "", $self->a, $self->op, $self->b
	    }
	}
	
	# Создаём простой объект:
	Calculator->new(a=>1, op=>"+", b=>2)->get # => 3
	
	# Через создание объекта запроса:
	use Aion::Request;
	my $request = Aion::Request->new(SLUG => {a => 5, b => 6}, QUERY_STRING => "op=%2B");
	my $calc = Calculator->new_from_request($request);
	
	$calc->get  # => 11
	
	$calc       # --> Calculator->new(a=>1, op=>"+", b=>2)
	

=head1 DESCRIPTION

=head1 LICENSE

© Yaroslav O. Kosmina
2022
