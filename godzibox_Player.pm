package GodziBox_Player;
#####################################################
# GodziBox - Tournament servers coordination system
# Copyright (C) 2007 Association Godzilan
# http://www.godzilan.net/
# Elektordi & JBG - Oct. 2007
#####################################################
#
# HLstats_Player.pm - HLstats Player class
# http://sourceforge.net/projects/hlstats/
#
# Copyright (C) 2001  Simon Garner
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#


#
# Constructor
#

sub new
{
	my $class_name = shift;
	my %params = @_;
	
	my $self = {};
	bless($self, $class_name);
	
	# Initialise Properties
	$self->{userid} = 0;
	$self->{server} = "";
	$self->{name} = "";
	$self->{uniqueid} = "";
	
	$self->{playerid} = 0;
	$self->{clan} = 0;
	$self->{kills}  = 0;
	$self->{deaths} = 0;
	$self->{suicides} = 0;
	$self->{skill}  = 1000;
	$self->{game}   = 0;
	$self->{team}   = "";
	$self->{role}   = "";
	$self->{timestamp} = 0;
	
	# Set Property Values
	
	die("HLstats_Player->new(): must specify player's uniqueid\n")
		unless (defined($params{uniqueid}));
	
	die("HLstats_Player->new(): must specify player's name\n")
		unless ($params{name} ne "");
	
	while (my($key, $value) = each(%params))
	{
		if ($key ne "name" && $key ne "uniqueid")
		{
			$self->set($key, $value);
		}
	}
	
	&::printNotice("Created new player object " . $self->getInfoString());
	
	return $self;
}


#
# Set property 'key' to 'value'
#

sub set
{
	my ($self, $key, $value, $no_updatetime) = @_;
	
	if (defined($self->{$key}))
	{
		unless ($no_updatetime)
		{
			$self->{timestamp} = $::ev_unixtime;
		}
		
		if ($self->get($key) eq $value)
		{
			if ($g_debug > 2)
			{
				&printNotice("Hlstats_Player->set ignored: Value of \"$key\" is already \"$value\"");
			}
			return 0;
		}
		
		$self->{$key} = $value;
		return 1;
	}
	else
	{
		warn("HLstats_Player->set: \"$key\" is not a valid property name\n");
		return 0;
	}
}


#
# Increment (or decrement) the value of 'key' by 'amount' (or 1 by default)
#

sub increment
{
	my ($self, $key, $amount, $no_updatetime) = @_;
	
	$amount = int($amount);
	$amount = 1 if ($amount == 0);
	
	my $value = $self->get($key);
	$self->set($key, $value + $amount, $no_updatetime);
}


#
# Get value of property 'key'
#

sub get
{
	my ($self, $key) = @_;
	
	if (defined($self->{$key}))
	{
		return $self->{$key};
	}
	else
	{
		warn("HLstats_Player->get: \"$key\" is not a valid property name\n");
	}
}


#
# Update player timestamp (time of last event for player - used to detect idle
# players)
#

sub updateTimestamp
{
	my ($self, $timestamp) = @_;
	
	$timestamp = $::ev_unixtime
		unless ($timestamp);
	
	$self->{timestamp} = $timestamp;
	
	return $timestamp;
}


#
# Returns a string of information about the player.
#

sub getInfoString
{
	my ($self) = @_;
	
	my $name = $self->get("name");
	my $playerid = $self->get("playerid");
	my $userid   = $self->get("userid");
	my $uniqueid = $self->get("uniqueid");
	my $team = $self->get("team");

	return "\"$name\" \<P:$playerid,U:$userid,W:$uniqueid,T:$team\>";
}


1;
