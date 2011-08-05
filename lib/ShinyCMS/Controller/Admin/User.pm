package ShinyCMS::Controller::Admin::User;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }


=head1 NAME

ShinyCMS::Controller::Admin::User

=head1 DESCRIPTION

Controller for ShinyCMS user administration functions.

=head1 METHODS

=cut


=head2 base

Set up the path.

=cut

sub base : Chained( '/' ) : PathPart( 'admin/user' ) : CaptureArgs( 0 ) {
	my ( $self, $c ) = @_;
	
	# Stash the upload_dir setting
	$c->stash->{ upload_dir } = $c->config->{ upload_dir };
	
	# Stash the controller name
	$c->stash->{ controller } = 'Admin::User';
}


=head2 index

Bounce to list of users.

=cut

sub index : Chained( 'base' ) : PathPart( '' ) : Args( 0 ) {
	my ( $self, $c ) = @_;
	
	$c->go( 'list_users' );
}


# ========== ( Users ) ==========

=head2 list_users

List all users.

=cut

sub list_users : Chained( 'base' ) : PathPart( 'list' ) : Args( 0 ) {
	my ( $self, $c ) = @_;
	
	# Check to make sure user has the required permissions
	return 0 unless $c->model( 'Authorisation' )->user_exists_and_can({
		action   => 'list all users', 
		role     => 'User Admin',
		redirect => '/user'
	});
	
	# Stash the list of users
	my @users = $c->model( 'DB::User' )->search(
		{},
		{
			order_by => 'username',
		},
	);
	$c->stash->{ users } = \@users;
}


=head2 add_user

Add a new user.

=cut

sub add_user : Chained( 'base' ) : PathPart( 'add' ) : Args( 0 ) {
	my ( $self, $c, $uid ) = @_;
	
	# Check to make sure user has the required permissions
	return 0 unless $c->model( 'Authorisation' )->user_exists_and_can({
		action   => 'add users', 
		role     => 'User Admin',
		redirect => '/user'
	});
	
	# Stash the list of roles
	my @roles = $c->model( 'DB::Role' )->all;
	$c->stash->{ roles } = \@roles;
	
	# Set the template
	$c->stash->{ template } = 'admin/user/edit_user.tt';
}


=head2 edit_user

Edit user details.

=cut

sub edit_user : Chained( 'base' ) : PathPart( 'edit' ) : Args( 1 ) {
	my ( $self, $c, $user_id ) = @_;
	
	# Check to make sure user has the required permissions
	return 0 unless $c->model( 'Authorisation' )->user_exists_and_can({
		action   => 'edit a user', 
		role     => 'User Admin',
		redirect => '/user'
	});
	
	# Stash user details
	$c->stash->{ user } = $c->model( 'DB::User' )->find({
		id => $user_id,
	});
	
	# Stash the list of roles
	my @roles = $c->model( 'DB::Role' )->search;
	$c->stash->{ roles } = \@roles;
}


=head2 edit_do

Update db with new user details.

=cut

sub edit_do : Chained( 'base' ) : PathPart( 'edit-do' ) : Args( 0 ) {
	my ( $self, $c ) = @_;
	
	# Check to make sure user has the required permissions
	return 0 unless $c->model( 'Authorisation' )->user_exists_and_can({
		action   => 'edit a user', 
		role     => 'User Admin',
		redirect => '/user'
	});
	
	# Get the user ID for the user being edited
	my $user_id = $c->request->param( 'user_id' );
	
	my $user = $c->model( 'DB::User' )->find({ id => $user_id });
	
	# Process deletions
	if ( defined $c->request->params->{ delete } && $c->request->param( 'delete' ) eq 'Delete' ) {
		$user->comments->delete;
		$user->user_roles->delete;
		$user->delete;
		
		# Shove a confirmation message into the flash
		$c->flash->{ status_msg } = 'User deleted';
		
		# Bounce to the default page
		$c->response->redirect( $c->uri_for( 'list' ) );
		return;
	}
	
	# Get the new email from the form
	my $email = $c->request->params->{ email };
	
	# Check it for validity
	my $email_valid = Email::Valid->address(
		-address  => $email,
		-mxcheck  => 1,
		-tldcheck => 1,
	);
	unless ( $email_valid ) {
		$c->flash->{ error_msg } = 'You must set a valid email address.';
		$c->go( 'edit_user', $user_id ) if $user_id;
		$c->go( 'edit_user' );
	}
	
	# Upload new profile pic, if one has been selected
	my $profile_pic;
	$profile_pic = $user->profile_pic if $user;
	if ( $c->request->param( 'profile_pic' ) ) {
		my $file = $c->request->upload( 'profile_pic' );
		my $limit = $c->config->{ User }->{ profile_pic_file_size };
		my $unit = 'KB';
		my $size = $limit / 1024;
		my $mb   = $size  / 1024;
		$unit    = 'MB' if $mb >= 1;
		$size    = $mb  if $mb >= 1;
		if ( $file->size > $limit ) {
			$c->flash->{ error_msg } = 'Profile pic must be less than '. $size .' '. $unit;
			$c->response->redirect( $c->uri_for( 'edit' ) );
			return;
		}
		$profile_pic = $file->filename;
		# Save file to appropriate location
		my $username;
		$username = $user->username if $user;
		$username = $c->request->param( 'username' ) unless $user;
		my $path = $c->path_to( 'root', 'static', $c->stash->{ upload_dir }, 'user-profile-pics', $username );
		mkdir $path unless -d $path;
		my $save_as = $path .'/'. $profile_pic;
		$file->copy_to( $save_as ) or die "Failed to write file '$save_as' because: $!,";
	}
	
	# Update or create user record
	if ( $user_id ) {
		# Update user info
		$user->update({
			firstname     => $c->request->param( 'firstname'     ) || undef,
			surname       => $c->request->param( 'surname'       ) || undef,
			display_name  => $c->request->param( 'display_name'  ) || undef,
			display_email => $c->request->param( 'display_email' ) || undef,
			website       => $c->request->param( 'website'       ) || undef,
			location      => $c->request->param( 'location'      ) || undef,
			postcode      => $c->request->param( 'postcode'      ) || undef,
			bio           => $c->request->param( 'bio'           ) || undef,
			profile_pic   => $profile_pic                          || undef,
			email         => $email,
			admin_notes   => $c->request->param( 'admin_notes'   ) || undef,
		});
	}
	else {
		# Create new user
		$user = $c->model( 'DB::User' )->create({
			username      => $c->request->param( 'username'      ) || undef,
			password      => $c->request->param( 'password'      ) || undef,
			firstname     => $c->request->param( 'firstname'     ) || undef,
			surname       => $c->request->param( 'surname'       ) || undef,
			display_name  => $c->request->param( 'display_name'  ) || undef,
			display_email => $c->request->param( 'display_email' ) || undef,
			website       => $c->request->param( 'website'       ) || undef,
			location      => $c->request->param( 'location'      ) || undef,
			postcode      => $c->request->param( 'postcode'      ) || undef,
			bio           => $c->request->param( 'bio'           ) || undef,
			profile_pic   => $profile_pic                          || undef,
			email         => $email,
			admin_notes   => $c->request->param( 'admin_notes'   ) || undef,
		});
	}
	
	# Wipe existing user roles
	$user->user_roles->delete;
	
	# Extract user roles from form
	foreach my $input ( keys %{ $c->request->params } ) {
		if ( $input =~ m/^role_(\d+)$/ ) {
			$user->user_roles->create({ role => $1 });
		}
	}
	
	# Shove a confirmation message into the flash
	$c->flash->{status_msg} = 'Details updated';
	
	# Bounce back to the 'edit' page
	$c->response->redirect( $c->uri_for( 'edit', $user->id ) );
}


=head2 change_password

Change user password.

=cut

sub change_password : Chained( 'base' ) : PathPart( 'change-password' ) : Args( 1 ) {
	my ( $self, $c, $user_id ) = @_;
	
	# Check to make sure user has the required permissions
	return 0 unless $c->model( 'Authorisation' )->user_exists_and_can({
		action   => "change a user's password", 
		role     => 'User Admin',
		redirect => '/user'
	});
	
	# Get the user details from the db
	my $user = $c->model( 'DB::User' )->find({
		id => $user_id,
	});
	
	$c->stash->{ user } = $user;
}


=head2 change_password_do

Update db with new password.

=cut

sub change_password_do : Chained( 'base' ) : PathPart( 'change-password-do' ) : Args( 0 ) {
	my ( $self, $c ) = @_;
	
	# Check to make sure user has the required permissions
	return 0 unless $c->model( 'Authorisation' )->user_exists_and_can({
		action   => "change a user's password", 
		role     => 'User Admin',
		redirect => '/user'
	});
	
	# Fetch the user
	my $user = $c->model( 'DB::User' )->find({
		id => $c->request->param( 'user_id' ),
	});
	
	# Get the new password from the form
	my $password_one = $c->request->param( 'password_one' );
	my $password_two = $c->request->param( 'password_two' );
	
	# Verify they're both the same
	my $matching_passwords = 1 if $password_one eq $password_two;
	
	if ( $matching_passwords ) {
		# Update password in database
		$user->update({
			password => $password_one,
		});
		
		# Shove a confirmation message into the flash
		$c->flash->{ status_msg } = 'Password changed';
	}
	else {
		# Shove an error message into the flash
		$c->flash->{ error_msg } = 'Passwords did not match';
	}
	
	# Bounce back to the user list
	$c->response->redirect( $c->uri_for( 'list' ) );
}


# ========== ( Roles ) ==========

=head2 list_roles

List all the roles.

=cut

sub list_roles : Chained( 'base' ) : PathPart( 'role/list' ) : Args( 0 ) {
	my ( $self, $c ) = @_;
	
	# Check to make sure user has the right to view roles
	return 0 unless $c->model( 'Authorisation' )->user_exists_and_can({
		action => 'view the list of roles', 
		role   => 'User Admin',
	});
	
	my @roles = $c->model( 'DB::Role' )->all;
	$c->stash->{ roles } = \@roles;
}


=head2 add_role

Add a role.

=cut

sub add_role : Chained( 'base' ) : PathPart( 'role/add' ) : Args( 0 ) {
	my ( $self, $c ) = @_;
	
	# Check to see if user is allowed to add roles
	return 0 unless $c->model( 'Authorisation' )->user_exists_and_can({
		action => 'add a new role', 
		role   => 'User Admin',
	});
	
	$c->stash->{ template } = 'admin/user/edit_role.tt';
}


=head2 add_role_do

Process adding a new role.

=cut

sub add_role_do : Chained( 'base' ) : PathPart( 'role/add-do' ) : Args( 0 ) {
	my ( $self, $c ) = @_;
	
	# Check to see if user is allowed to add roles
	return 0 unless $c->model( 'Authorisation' )->user_exists_and_can({
		action => 'add a new role', 
		role   => 'User Admin',
	});
	
	# Create role
	my $role = $c->model( 'DB::Role' )->create({
		role => $c->request->param( 'role' ),
	});
	
	# Shove a confirmation message into the flash
	$c->flash->{ status_msg } = 'Template details saved';
	
	# Bounce back to the template list
	$c->response->redirect( $c->uri_for( 'role/list' ) );
}


=head2 get_role

Stash details of a role.

=cut

sub get_role : Chained( 'base' ) : PathPart( 'role' ) : CaptureArgs( 1 ) {
	my ( $self, $c, $role_id ) = @_;
	
	$c->stash->{ role } = $c->model( 'DB::Role' )->find({ id => $role_id });
	
	unless ( $c->stash->{ role } ) {
		$c->flash->{ error_msg } = 
			'Specified role not found - please select from the options below';
		$c->go('list_roles');
	}
}


=head2 edit_role

Edit a role.

=cut

sub edit_role : Chained( 'get_role' ) : PathPart( 'edit' ) : Args( 0 ) {
	my ( $self, $c ) = @_;
	
	# Bounce if user isn't logged in and a user admin
	return 0 unless $c->model( 'Authorisation' )->user_exists_and_can({
		action => 'edit a role', 
		role   => 'User Admin',
	});
}


=head2 edit_role_do

Process a role edit.

=cut

sub edit_role_do : Chained( 'get_role' ) : PathPart( 'edit-do' ) : Args( 0 ) {
	my ( $self, $c ) = @_;
	
	# Check to see if user is allowed to edit roles
	return 0 unless $c->model( 'Authorisation' )->user_exists_and_can({
		action => 'edit a role', 
		role   => 'User Admin',
	});
	
	# Process deletions
	if ( $c->request->param( 'delete' ) eq 'Delete' ) {
		$c->stash->{ role }->user_roles->delete;
		$c->stash->{ role }->delete;
		
		# Shove a confirmation message into the flash
		$c->flash->{ status_msg } = 'Role deleted';
		
		# Bounce to the 'view all roles' page
		$c->response->redirect( $c->uri_for( 'role/list' ) );
		return;
	}
	
	# Update role
	$c->stash->{ role }->update({
		role => $c->request->param( 'role' ),
	});
	
	# Shove a confirmation message into the flash
	$c->flash->{ status_msg } = 'Role updated';
	
	# Bounce back to the list of roles
	$c->response->redirect( $c->uri_for( 'role/list' ) );
}


# ========== ( Login ) ==========

=head2 login

Login logic.

=cut

sub login : Chained( 'base' ) : PathPart( 'login' ) : Args( 0 ) {
	my ( $self, $c ) = @_;
	
	# If we already have a logged-in user, bounce them to some sort of useful page
	if ( $c->user_exists ) {
		$c->response->redirect( $c->uri_for( '/user', $c->user->username ) );
		$c->response->redirect( $c->uri_for( '/admin', 'user', 'list' ) )
			if $c->user->has_role( 'User Admin' );
		$c->response->redirect( $c->uri_for( '/events', 'list' ) )
			if $c->user->has_role( 'Events Admin' );
		$c->response->redirect( $c->uri_for( '/blog', 'list' ) )
			if $c->user->has_role( 'Blog Author' );
		$c->response->redirect( $c->uri_for( '/admin', 'pages', 'list' ) )
			if $c->user->has_role( 'CMS Page Editor' );
		return;
	}
	
	# Get the username and password from form
	my $username = $c->request->param( 'username' ) || undef;
	my $password = $c->request->param( 'password' ) || undef;
	
	# If the username and password values were found in form
	if ( $username && $password ) {
		# Check the account is active
		my $check = $c->model( 'DB::User' )->find({ username => $username });
		unless ( $check ) {
			$c->stash->{ error_msg } = "Bad username or password.";
			return;
		}
		unless ( $check->active ) {
			$c->flash->{ error_msg } = 'Account unavailable.';
			$c->response->redirect( $c->uri_for( '/' ) );
			return;
		}
		# Attempt to log the user in
		if ( $c->authenticate({ username => $username, password => $password }) ) {
			# If successful, bounce them back to the referring page (or some useful page)
			if ( $c->request->param( 'redirect' ) 
					and $c->request->param( 'redirect' ) !~ m!admin/user/login! ) {
				$c->response->redirect( $c->request->param( 'redirect' ) );
			}
			else {
				$c->response->redirect( $c->uri_for( '/user', $username ) );
				$c->response->redirect( $c->uri_for( '/admin', 'user', 'list' ) )
					if $c->user->has_role( 'User Admin' );
				$c->response->redirect( $c->uri_for( '/events', 'list' ) )
					if $c->user->has_role( 'Events Admin' );
				$c->response->redirect( $c->uri_for( '/blog', 'list' ) )
					if $c->user->has_role( 'Blog Author' );
				$c->response->redirect( $c->uri_for( '/admin', 'pages', 'list' ) )
					if $c->user->has_role( 'CMS Page Editor' );
			}
			return;
		}
		else {
			# Set an error message
			$c->stash->{ error_msg } = "Bad username or password.";
		}
	}
}



=head1 AUTHOR

Denny de la Haye <2011@denny.me>

=head1 COPYRIGHT

ShinyCMS is copyright (c) 2009-2011 Shiny Ideas (www.shinyideas.co.uk).

=head1 LICENSE

This program is free software: you can redistribute it and/or modify it 
under the terms of the GNU Affero General Public License as published by 
the Free Software Foundation, either version 3 of the License, or (at 
your option) any later version.

You should have received a copy of the GNU Affero General Public License 
along with this program (see docs/AGPL-3.0.txt).  If not, see 
http://www.gnu.org/licenses/

=cut

__PACKAGE__->meta->make_immutable;

1;

