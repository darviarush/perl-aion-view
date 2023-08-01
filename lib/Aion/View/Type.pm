package Aion::View::Type;
# Базовый класс для типов и преобразователей

use common::sense;

use Scalar::Util qw/looks_like_number/;
require DDP;

use overload
	"fallback" => 1,
	"&{}" => sub { my ($self) = @_; sub { $self->test } },	# Чтобы тип мог быть выполнен
	'""' => \&stringify,									# Отображать тип в трейсбеке в строковом представлении
	"|" => sub {
		my ($type1, $type2) = @_;
		__PACKAGE__->new(name => "Union", args => [$type1, $type2], test => sub { $type1->test || $type2->test });
	},
	"&" => sub {
		my ($type1, $type2) = @_;
		__PACKAGE__->new(name => "Intersection", args => [$type1, $type2], test => sub { $type1->test && $type2->test });
	},
	"~" => sub {
		my ($type1) = @_;
		__PACKAGE__->new(name => "Exclude", args => [$type1], test => sub { !$type1->test });
	},
	"~~" => sub {
		my ($type, $z) = @_;
		$type->include($z)
	};

# конструктор
# * args (ArrayRef) — Список аргументов.
# * name (Str) — Имя метода.
# * test (CodeRef) — чекер.
# * coerce (CodeRef) — конвертер.
sub new {
	my $cls = shift;
	bless {@_}, ref $cls || $cls;
}

# Символьное представление значения
sub _val_to_str {
	my ($v) = @_;
	!defined($v)			? "undef":
	looks_like_number($v)	? $v:
	ref($v)					? DDP::np($v, max_depth => 2, array_max => 13, hash_max => 13, string_max => 255):
	do {
		$v =~ s/[\\']/\\$&/g;
		$v =~ s/^/'/;
		$v =~ s/\z/'/;
		$v
	}
}

# Строковое представление
sub stringify {
	my ($self) = @_;
	join "", $self->{name}, $self->{args}? ("[", join(", ", map {
		UNIVERSAL::isa($_, __PACKAGE__)? $_->stringify: _val_to_str($_) } @{$self->{args}}), "]") : ();
}

# Тестировать значение в $_
our $SELF;
sub test {
	my ($self) = @_;
	my $save = $SELF;
	$SELF = $self;
	my $ok = $self->{test}->();
	$SELF = $save;
	$ok
}

# Инициализировать тип
sub init {
	my ($self) = @_;
	my $save = $SELF;
	$SELF = $self;
	$self->{init}->();
	$SELF = $save;
	$self
}

# Является элементом множества описываемого типом
sub include {
	(my $self, local $_) = @_;
	$self->test
}

# Не является элементом множества описываемого типом
sub exclude {
	(my $self, local $_) = @_;
	!$self->test
}

# Сообщение об ошибке
sub detail {
	my ($self, $val, $name) = @_;
	$self->{detail}? $self->{detail}->():
		"Свойство $name должно иметь тип " . $self->stringify . ". $name же = " . _val_to_str($val)
}

# Валидировать значение в параметре
sub validate {
	(my $self, local $_, my $name) = @_;
	die $self->detail($_, $name) if !$self->test;
}

# Преобразовать значение в параметре и вернуть преобразованное
sub coerce {
	(my $self, local $_) = @_;
	$self->{from}->test? $self->{coerce}->(): $_
}

# Создаёт функцию для типа
sub make {
	my ($self, $pkg) = @_;

	die "init_where не сработает в $self" if $self->{init};

	my $pkg = $pkg // caller;
	my $var = "\$$self->{name}";
	
	my $code = "package $pkg { 
	my $var = \$self;
	sub $self->{name} () { $var } 
}";
	eval $code;
	die if $@;

	$self
}

# Создаёт функцию для типа c аргументом
sub make_arg {
	my ($self, $pkg) = @_;

	my $pkg = $pkg // caller;
	my $var = "\$$self->{name}";
	my $init = $self->{init}? "->init": "";

	my $code = "package $pkg {
	
	my $var = \$self;
	
	sub $self->{name} (\$) {
		Aion::View::Type->new(
			%$var,
			args => \$_[0],
		)$init
	}
}";
	eval $code;
	die if $@;

	$self
}

# Создаёт функцию для типа c аргументом или без
sub make_maybe_arg {
	my ($self, $pkg) = @_;

	my $pkg = $pkg // caller;
	my $var = "\$$self->{name}";
	my $init = $self->{init}? "->init": "";

	my $code = "package $pkg {
	
	my $var = \$self;
	
	sub $self->{name} (;\$) {
		\@_==0? $var:
		Aion::View::Type->new(
			%$var,
			args => \$_[0],
			test => ${var}->{a_test},
		)$init
	}
}";
	eval $code;
	die if $@;

	$self
}


1;