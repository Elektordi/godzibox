package GodziBox_Server;
#####################################################
# GodziBox - Tournament servers coordination system
# Copyright (C) 2007 Association Godzilan
# http://www.godzilan.net/
# Elektordi & JBG - Oct. 2007
#####################################################
#
# Based on HLstats_Server.pm - HLstats Server class
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

use POSIX qw(strftime);
use Digest::MD5 qw(md5_base64);

sub new
{
	my ($class_name, $serverId, $address, $port, $game, $name) = @_;
	
	my ($self) = {};
	
	bless($self, $class_name);
	
	$self->{id}      = $serverId;
	$self->{address} = $address;
	$self->{port}    = $port;
	$self->{game}    = $game;
	
	$self->{name}	= $name;
	$self->{map}     = "";
	$self->{numplayers} = 0;
	$self->{lastlog} = 0;

	$self->{source} = 0;

	$self->{t1code} = "";
	$self->{t2code} = "";
	$self->{t1trig} = "";
	$self->{t1trig} = "";

	$self->{t1name} = "";
	$self->{t2name} = "";

	$self->{t1ready} = 0;
	$self->{t2ready} = 0;

	$self->{t1score} = 0;
	$self->{t2score} = 0;
	
	$self->{lastsay} = 0;
	$self->{matchid} = 0;
	$self->{turn} = 0;
	$self->{round} = 0;
	$self->{password} = "";
	$self->{matchmap} = "";
	$self->{rules} = "";
	$self->{overtime} = 0;
	$self->{step} = 0;

	$self->{maxrounds} = 0; # Max rounds per turn (2 turns)
	$self->{allowtie} = 0; # Don't overtime if draw
	$self->{breakpoint} = 0; # Stop match if score > maxrounds +1
	$self->{kickonmapload} = 0; # Kick on map load
	$self->{randomsides} = 0; # T1 will not always start as CT

	# Find teams names
	my $query = "SELECT IsSource, Team1, Team2, Team1Trigger, Team2Trigger FROM Games WHERE GameId = $game;";
	my $result = ::doQuery($query);
	if (!$result->rows)
	{
		print("!! Unknow Game #$game \n");
	}
	($issource, $t1code, $t2code, $t1trig, $t2trig) = $result->fetchrow_array;

	$self->{source} = $issource;
	$self->{t1code} = $t1code;
	$self->{t2code} = $t2code;
	$self->{t1trig} = $t1trig;
	$self->{t2trig} = $t2trig;

	return $self;
}

sub say
{
	# /!\ Max 63 caractères /!\

	my ($self, $message) = @_;
	::say($message, $self->{address}, $self->{port});
}

sub rcon
{
	my ($self, $command) = @_;
	::rcon($command, $self->{address}, $self->{port});
}

sub think
{
	my ($self) = @_;
	return 0 if($self->{lastlog} == 0);

	# Now server think !

	my $query = "
                SELECT
                        MatchId,
			Player1Name,
			Player2Name,
			Action,
			Status,
			Map,
			Rules,
			MaxRounds,
			AllowTie,
			BreakPoint,
			Password,
			KickOnMapLoad,
			RandomSides,
			MatchIsOvertime
                FROM
                        Matchs
                WHERE
                        Status < 5 AND
                        ServerID = $self->{id}
        ";
        my $result = ::doQuery($query);

        if (!$result->rows)
        {
		if($self->{matchid} > 0)
		{
			print("-> Match #$self->{matchid} unlinked from server #$self->{id} !\n");
		}
		$self->{matchid} = 0;
		$result->finish;
		return 0;
	}

	my ($matchid, $t1name, $t2name, $action, $status, $map, $rules, $maxrounds, $allowtie, $breakpoint, $password, $kickonmapload, $randomsides, $isovertime) = $result->fetchrow_array;

	if($self->{matchid} > 0)
	{
		# Match en cours !

		if($matchid != $self->{matchid})
		{
			print("!! Match conflict for server $self->{id} ! Id is $self->{matchid} here and $matchid in SQL !\n");
			print("!! Act like match cancel and starting a new match over...\n");
			$self->{matchid} = 0;
			$self->disconnect(); # Emergency stop
		}

		# Mise à jour
		$self->{t1name} = $t1name;
		$self->{t2name} = $t2name;
		$self->{maxrounds} = $maxrounds;
		$self->{allowtie} = $allowtie;
		$self->{breakpoint} = $breakpoint;
		$self->{kickonmapload} = $kickonmapload;

		if(!($self->{password} eq $password))
		{
			print("++ Changing password for match #$matchid\n");
			$self->rcon("password $password");
			$self->{password} = $password;
		}
		# print("-- Refresh ok for match #$matchid\n");
	}
	else
	{
		# Nouveau match !
        	$self->{t1name} = $t1name;
        	$self->{t2name} = $t2name;
        	$self->{t1ready} = 0;
        	$self->{t2ready} = 0;
        	$self->{t1score} = 0;
        	$self->{t2score} = 0;
        	$self->{lastsay} = 0;
        	$self->{turn} = 0;
		$self->{warmup} = 0;
		if($status == 1)
		{
			$self->{turn} = 1;
			$self->{warmup} = 1;
		}
		if($status == 2)
		{
			$self->{turn} = 1;
			$self->{warmup} = 0;
		}
		if($status == 3)
		{
			$self->{turn} = 2;
			$self->{warmup} = 1;
		}
		if($status == 4)
		{
			$self->{turn} = 2;
			$self->{warmup} = 0;
		}

        	$self->{round} = 0;
		$self->{step} = 0;
        	$self->{password} = $password;
        	$self->{matchmap} = $map;
        	$self->{rules} = $rules;
        	$self->{overtime} = $isovertime;
	        $self->{maxrounds} = $maxrounds;
	        $self->{allowtie} = $allowtie;
	        $self->{breakpoint} = $breakpoint;
	        $self->{kickonmapload} = $kickonmapload;
	        $self->{randomsides} = $randomsides;

        	$self->{matchid} = $matchid;
		print("-> Match $matchid ($t1name vs $t2name) linked to server #$self->{id}...\n");
	}
	$result->finish;

	if($self->{warmup})
	{
		if($self->{lastsay}==10)
		{
			$self->say("Vous êtes sur le serveur $self->{name}. Il est ".strftime("%Hh%Mm%Ss",localtime())." !");
		}
		if($self->{lastsay}==20)
		{
			$self->say("Warm up du match $t1name vs $t2name (tour ".$self->{turn}.")...");
		}
		if($self->{lastsay}==30)
		{
			$self->say("Chaque équipe doit dire 'ready' quand elle est prête !");
		}
		if($self->{lastsay}==40)
		{
			$self->say("Pour annuler une commande ready, dites 'stop'...");
		}
		if($self->{lastsay}==50)
		{
			$self->say("Pour toute question, n'hésitez pas à demander à l'admin !");
			$self->{lastsay}=0;
		}
		if($self->{lastsay}%10 == 5 && $self->{lastsay}<100)
		{
			$t1r = "(En attente)";
			$t1r = "(Prêts)" if($self->{t1ready});
			$t2r = "(En attente)";
			$t2r = "(Prêts)" if($self->{t2ready});

			$t1code = $self->{t1code};
			$t2code = $self->{t2code};

			if($self->{turn}==1)
			{
				$self->say("[Equipes] $t1code=$t1name $t1r - $t2code=$t2name $t2r");
			}
			else
			{
				# $t1ready and $t2ready are (in order) CT and T, not Teams1 and Team2...
				$self->say("[Equipes] $t1code=$t2name$t1r - $t2code=$t1name$t2r");
			}

			$self->{lastsay} = 99 if($self->{t1ready} && $self->{t2ready});
		}
		if($self->{lastsay}==100)
		{
			$self->say("Les deux équipes sont prêtes ! Match dans 30 secondes...");
		}
		if($self->{lastsay}==110)
		{
			$self->say("(En disant 'stop' vous pouvez arrêter le compte à rebours !)");
			$self->{lastsay}=190;
		}
		if($self->{lastsay}==200)
		{
			$self->say("***** COMPTE A REBOURS FINAL *****");
			$self->say("Le match $t1name vs $t2name va démarrer dans 10 secondes...");
		}
		if($self->{lastsay}==201) { $self->say("9 secondes..."); }
		if($self->{lastsay}==202) { $self->say("8 secondes..."); }
		if($self->{lastsay}==203) { $self->say("7 secondes..."); }
		if($self->{lastsay}==204) { $self->say("6 sec..."); }
		if($self->{lastsay}==205) { $self->say("5 sec..."); }
		if($self->{lastsay}==206) { $self->say("4 sec..."); }
		if($self->{lastsay}==207) { $self->say("3..."); }
		if($self->{lastsay}==208)
		{
			$self->rcon("sv_restartround 1"); # To prevent scoring when the round finished on match start
			$self->say("2...");
		}
		if($self->{lastsay}==209)
		{
			$self->rcon("sv_restartround 1");
			$self->say("1...");
		}
		if($self->{lastsay}==210)
		{
			$self->say("En jeu !");
			$self->{warmup} = 0;
			$self->{lastsay} = 0;
			$self->status(2) if($self->{turn}==1);
			$self->status(4) if($self->{turn}==2);
		}
		$self->{lastsay}++;
	}
	else
	{
		$self->say("Score a l'issue de la manche n°$self->{turn}:") if($self->{lastsay}==102);
		$self->say("$self->{t1name} => $self->{t1score}") if($self->{lastsay}==104);
		$self->say("$self->{t2name} => $self->{t2score}") if($self->{lastsay}==106);
		$self->say("Les scores ont été envoyés à l'admin...") if($self->{lastsay}==108);
		if($self->{turn}==1)
		{
			$self->say("Une seconde manche va avoir lieu...") if($self->{lastsay}==110);
			$self->say("Après le rechargement de la map,") if($self->{lastsay}==112);
			$self->say("merci de bien vouloir changer d'équipe !") if($self->{lastsay}==113);
			$self->say("Le second warm-up va maintenant commencer...") if($self->{lastsay}==114);
			if($self->{lastsay}==116)
			{
				$self->rcon("sv_restartround 1");
				$self->{turn} = 2;
				$self->{warmup} = 1;
				$self->{lastsay} = 0;
				$self->{t1score} = 0;
				$self->{t2score} = 0;
				$self->status(3);
			}
		}
		else
		{
			$self->say("Les deux manches sont terminées !") if($self->{lastsay}==110);
			$self->say("Le vainqueur du match est: XXX") if($self->{lastsay}==112);
			$self->say("Scores: 00 à 00") if($self->{lastsay}==114);
			$self->say("Vous pouvez maintenant vous déconnecter...") if($self->{lastsay}==116);
			$self->say("Arrêt du serveur de jeu !") if($self->{lastsay}==118);
			if($self->{lastsay}==118)
			{
				$self->disconnect();
				$self->status(5);
				::doQuery("UPDATE Matchs SET ServerId = 0 WHERE MatchId = $matchid");
				$self->{matchid}=0;
				$self->{lastsay}=0;
			}
		}

		$self->{lastsay}++ if($self->{lastsay}>99);
	}

	if($action>0)
	{
		if($action == 1)
		{
			# Start server
                        if($self->{step}==1 && $self->{map} eq $self->{matchmap})
                        {
				$self->rcon("exec rules/$rules.cfg");
				$self->hostname("$t1name vs $t2name");
				$self->status(1);
				$self->{turn}=1;
				$self->{warmup}=1;
                                $self->{step}=99;
                        }
                        if($self->{step}==0)
                        {
				$self->say("Le serveur va servir au match $t1name vs $t2name !");
				$self->say("Réinitialisation...");
				$self->rcon("sv_password $password");
                                $self->rcon("map $self->{matchmap}");
                                $self->{step}=1;
				
                        }

		}
		elsif($action == 2)
		{
			# Stop server
			if($self->{step}==1)
			{
				$self->say("ATTENTION: Le serveur va maintenant s'arrêter...");
				$self->disconnect();
				$self->{step}=99;
				$self->status(0);
				$self->{matchid}=0;
				::doQuery("UPDATE Matchs SET ServerId = 0 WHERE MatchId = $matchid");
			}
			if($self->{step}==0)
			{
				$self->say("ATTENTION: Annulation du match ! (par admin)");
				$self->{step}=1;
			}
		}
		elsif($action == 5)
		{
			# Pausable
			$self->rcon("pausable 1");
			$self->say("Pause maintenant autorisée...");
			$self->{step}=99;
		}
		elsif($action == 6)
		{
			# Unpusable
			$self->rcon("pausable 0");
			$self->say("La pause n'est plus autorisée !");
			$self->{step}=99;
		}
		elsif($action == 7 && $self->{warmup})
		{
			# Force start
			$self->say("ATTENTION: Lancement du match demandé par l'admin !");
			$self->{lastsay} = 200;
			$self->{step}=99;
		}
		else
		{
			print("!! Unknow action $action on match #$matchid !!\n");
			$self->{step}=99; # Unstuck webadmin
		}

		if($self->{step}==99)
		{
			# Action done
	
			$self->{step}=0;
			::doQuery("UPDATE Matchs SET Action = 0 WHERE MatchId = $matchid");
		}

	} # ($action>0)

	return 1;
}

sub chatcommand
{
	my ($self,$chat,$player) = @_;

	return 0 unless($self->{warmup});

	if($chat eq "ready")
	{
		::printNotice("Got 'ready' from team $player->{team}\n");
		if($player->{team} =~ /$self->{t1code}/)
		{
			$self->{t1ready} = 1;
			$self->say("L'équipe $self->{t1name} est prête...");
		}

		if($player->{team} =~ /$self->{t2code}/)
		{
			$self->{t2ready} = 1;
			$self->say("L'équipe $self->{t2name} est prête...");
		}
	}
	elsif($chat eq "stop" && $self->{lastsay} > 100)
	{
		::printNotice("Got 'stop' from team $player->{team}\n");
		if($self->{lastsay} < 200)
		{
			if($player->{team} =~ /$self->{t1code}/)
			{
				 $self->{t1ready} = 0;
			}
			if($player->{team} =~ /$self->{t2code}/)
			{
				 $self->{t2ready} = 0;
			}
			$self->{lastsay} = 0;
			$self->say("Annulation du compte à rebours...");
		}
		else
		{
			 $self->say("Trop tard pour annuler...");
		}
	}
	elsif($chat eq "godzibox")
	{
		$self->say("Powered by GodziBox $g_version");
		$self->say("This program is a free software, GNU-GPL licensed.");
		$self->say("Copyrights Association Godzilan (www.godzilan.net)");
	}

	return 1;
}

sub changemap
{
	my ($self,$map) = @_;
	if($self->{kickonmapload})
	{
		$self->rcon("map $map");
	}
	else
	{
		$self->rcon("changelevel $map");
	}
}

sub status
{
	my ($self, $status) = @_;
	::printNotice("Match on server #$self->{id} changes status to $status.\n");
	::doQuery("UPDATE Matchs SET Status = $status WHERE MatchId = $self->{matchid}");
}

sub scoring
{
	my ($self, %scores) = @_;
	while (my($team, $score) = each(%scores))
	{
		$self->{t1score}=$score if($team eq $self->{t1trig});
		$self->{t2score}=$score if($team eq $self->{t2trig});
	}
	$set = "ScoreSet".$self->{turn};
	if($self->{turn}==1)
	{
		::doQuery("UPDATE Matchs SET Player1$set = $self->{t1score}, Player2$set = $self->{t2score} WHERE MatchId = $self->{matchid}");
	}
	else
	{
		::doQuery("UPDATE Matchs SET Player1$set = $self->{t2score}, Player2$set = $self->{t1score} WHERE MatchId = $self->{matchid}");
	}
	$self->{round} = $self->{t1score}+$self->{t2score};
	if($self->{round} >= $self->{maxrounds})
	{
		$self->say("$self->{maxrounds} rounds joués. Fin de la manche.");
		$self->{lastsay}=100;
	}
	else
	{
		$self->say("$self->{round} / $self->{maxrounds} rounds joués.");
	}
}

sub ping
{
	my ($self) = @_;
	$self->{lastlog} = time();
}

sub logattach
{
	my ($self) = @_;
	$self->rcon("logaddress ".$::g_ip." ".$::g_port);
	$self->rcon("log on");
}

sub hostname
{
	my ($self, $name) = @_;
	$self->rcon("hostname \"$name [$self->{name}]\"");
}

sub disconnect
{
	my ($self) = @_;
	# disconnect command seems not to work on new hlds releases !
	$self->say("Disconnecting server...");
	$self->hostname("OFFLINE");
	$self->rcon("sv_password ".md5_base64(time()));
	$self->rcon("map bounce");
}

1;
