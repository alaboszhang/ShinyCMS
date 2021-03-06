package ShinyCMS::Controller::Shop::Basket;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }


# TODO: Extend this to allow multiple named baskets for logged-in users


=head1 NAME

ShinyCMS::Controller::Shop::Basket

=head1 DESCRIPTION

Controller for ShinyCMS shop basket.

=head1 METHODS

=head2 base

Sets up the base part of the URL path.

=cut

sub base : Chained('/base') : PathPart('shop/basket') : CaptureArgs(0) {
	my ( $self, $c ) = @_;
	
	# Stash the controller name
	$c->stash( controller => 'Shop::Basket' );
	
	# Stash the basket
	my $basket = $self->get_basket( $c );
	$c->stash( basket => $basket );
}


=head2 create_basket

Create a new basket

=cut

sub create_basket : Private : Args(0) {
	my ( $self, $c ) = @_;
	
	# If the user is logged-in, link basket to user account
	if ( $c->user_exists ) {
		return $c->user->baskets->create({});
	}
	
	# If not a logged-in user, link basket to session
	$c->session;
	return $c->model('DB::Basket')->create({
		session => 'session:' . $c->sessionid,
	});
}


=head2 get_basket

Get the basket

=cut

sub get_basket : Private : Args(0) {
	my ( $self, $c ) = @_;
	
	# If the user is logged-in, find their basket by user ID
	if ( $c->user_exists ) {
		return $c->model('DB::Basket')->search(
			{
				user => $c->user->id,
			},
			{
				join     => 'basket_items',
				prefetch => 'basket_items',
			}
		)->single;
	}
	
	# If not a logged-in user, find by session ID
	return $c->model('DB::Basket')->search(
		{
			session => 'session:' . $c->sessionid,
			user    => undef,
		},
		{
			join     => 'basket_items',
			prefetch => 'basket_items',
		}
	)->single;
}


=head2 view_basket

Display the basket contents

=cut

sub view_basket : Chained('base') : PathPart('') : Args(0) {
	my ( $self, $c ) = @_;
}


=head2 add_item

Add an item to the basket

=cut

sub add_item : Chained('base') : PathPart('add-item') : Args(0) {
	my ( $self, $c ) = @_;
	
	# Create basket if we don't already have one
	$c->stash->{ basket } = $self->create_basket( $c ) 
		unless $c->stash->{ basket };
	
	# Add the item to the basket
	my $item = $c->model('DB::ShopItem')->find({
		id => $c->request->param('item_id'),
	});
	$c->stash->{ basket }->basket_items->create({
		item       => $item->id,
		quantity   => $c->request->param('quantity'),
		unit_price => $item->price,
	});
	
	# Set a status message
	$c->flash->{ status_msg } = 'Item added.';
	
	# Redirect to a return URL if specified, or to the basket otherwise
	if ( $c->request->param('return_url') ) {
		$c->response->redirect( $c->request->param('return_url') );
	}
	else {
		$c->response->redirect( $c->uri_for( 'view_basket' ) );
	}
}


=head2 update

Update items in the basket

=cut

sub update : Chained('base') : PathPart('update') : Args(0) {
	my ( $self, $c ) = @_;
	
	my $params = $c->request->params;
	
	foreach my $key ( keys %$params ) {
		next unless $key =~ m/^quantity_(\d+)$/;
		my $item_id = $1;
		
		if ( $params->{ $key } == 0 ) {
			# Remove the item
			$c->stash->{ basket }->basket_items->find({
				id => $item_id,
			})->delete;
	
			# Set a status message
			$c->flash->{ status_msg } = 'Item removed.';
		}
		else {
			# Update the item
			$c->stash->{ basket }->basket_items->find({
				id => $item_id,
			})->update({
				quantity => $params->{ $key },
			});
	
			# Set a status message
			$c->flash->{ status_msg } = 'Item updated.';
		}
	}
	
	# Redirect back to the basket
	$c->response->redirect( $c->uri_for( '' ) );
}


=head2 remove_item

Remove an item from the basket

=cut

sub remove_item : Chained('base') : PathPart('remove-item') : Args(0) {
	my ( $self, $c ) = @_;
	
	# Delete this item from the basket
	my $item = $c->stash->{ basket }->basket_items->search({
		item => $c->request->param('item_id'),
	})->delete;
	
	# Set a status message and redirect back to the basket
	$c->flash->{ status_msg } = 'Item removed.';
	$c->response->redirect( $c->uri_for( '' ) );
}



=head1 AUTHOR

Denny de la Haye <2013@denny.me>

=head1 COPYRIGHT

ShinyCMS is copyright (c) 2009-2013 Shiny Ideas (www.shinyideas.co.uk).

=head1 LICENSE

This program is free software: you can redistribute it and/or modify it 
under the terms of the GNU Affero General Public License as published by 
the Free Software Foundation, either version 3 of the License, or (at your 
option) any later version.

You should have received a copy of the GNU Affero General Public License 
along with this program (see docs/AGPL-3.0.txt).  If not, see 
http://www.gnu.org/licenses/

=cut

__PACKAGE__->meta->make_immutable;

1;

