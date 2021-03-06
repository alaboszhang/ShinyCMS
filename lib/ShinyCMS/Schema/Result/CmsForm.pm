use utf8;
package ShinyCMS::Schema::Result::CmsForm;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

ShinyCMS::Schema::Result::CmsForm

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::TimeStamp>

=item * L<DBIx::Class::EncodedColumn>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp", "EncodedColumn");

=head1 TABLE: C<cms_form>

=cut

__PACKAGE__->table("cms_form");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=head2 url_name

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=head2 redirect

  data_type: 'varchar'
  is_nullable: 1
  size: 200

=head2 action

  data_type: 'varchar'
  is_nullable: 0
  size: 20

=head2 email_to

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 template

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "url_name",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "redirect",
  { data_type => "varchar", is_nullable => 1, size => 200 },
  "action",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "email_to",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "template",
  { data_type => "varchar", is_nullable => 1, size => 100 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<cms_form_url_name>

=over 4

=item * L</url_name>

=back

=cut

__PACKAGE__->add_unique_constraint("cms_form_url_name", ["url_name"]);


# Created by DBIx::Class::Schema::Loader v0.07014 @ 2012-02-09 00:25:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7QtgiWSzkT0xgEVvWxRDKw



# EOF
__PACKAGE__->meta->make_immutable;
1;

