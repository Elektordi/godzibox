package GodziBox_Server;
#####################################################
# GodziBox - Tournament servers coordination system
# Copyright (C) 2007 Association Godzilan
# http://www.godzilan.net/
# Elektordi & JBG - Oct. 2007
#####################################################
#
# HLstats_Server.pm - HLstats Server class
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


sub new
{
	my ($class_name, $serverId, $address, $port, $game) = @_;
	
	my ($self) = {};
	
	bless($self, $class_name);
	
	$self->{id}      = $serverId;
	$self->{address} = $address;
	$self->{port}    = $port;
	$self->{game}    = $game;
	
	$self->{map}     = "";
	$self->{numplayers} = 0;

	$self->{t1name} = "";
	$self->{t2name} = "";

	$self->{t1ready} = 0;
	$self->{t2ready} = 0;

	$self->{t1score} = 0;
	$self->{t2score} = 0;
	
	$self->{lastsay} = 0;
	$self->{idmatch} = 0;
	$self->{turn} = 0;
	$self->{inmatch} = 0;
	$self->{round} = 0;
	$self->{password} = "";
	$self->{matchmap} = "";
	$self->{rules} = "";

	$self->{maxrounds} = 0;
	$self->{allowtie} = 0;
	$self->{breakpoint} = 0; # Stop match if score > maxrounds +1
	$self->{kickonmapload} = 0; # Kick on map load
	$self->{randomsides} = 0; # T1 will not always start as CT

	return $self;
}

1;
