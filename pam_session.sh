#!/usr/bin/env bash
#Copyright (C) 2015  Helal Uddin <helal00 at gmail.com>
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.

if [ -z "$PAM_RHOST" ] || [ -z "$PAM_USER" ] || [ -z "$PAM_TYPE" ] ; then
exit 1
fi

_remoteip="$(getent ahostsv4 $PAM_RHOST | grep STREAM | head -n 1 | cut -d ' ' -f 1)"
_user=$PAM_USER
_userhome=$(eval echo ~"$_user")
_roothome=$(eval echo ~root)
if ! grep -q "$_user" "$_roothome/.ipmanage/allowed" ; then
	exit 1
fi

if [ ! -d "$_userhome/.ipmanage" ] ; then
	mkdir -p "$_userhome/.ipmanage"
	chown "$_user" "$_userhome/.ipmanage"
fi
if [ "${PAM_TYPE}x" = "close_sessionx" ] && [ -n "$_remoteip" ] ; then
  if [ -f "$_userhome/.ipmanage/lastusedip" ] ; then
	_curipinmanage=$(cat "$_userhome/.ipmanage/lastusedip")
	_nodelete=1
	if [ -f "$_userhome/.ipmanage/nodel" ] ; then
		_nodelete=0
	fi
	if [ "$_nodelete" -eq 1 ] ; then
		if lsof -i -n | grep -E '\<sshd\>'| grep "(ESTABLISHED)" | grep -q "$_curipinmanage" ; then
			_nodelete=0
		fi	
	fi
	if [ "$_nodelete" -eq 1 ] ; then
		ufw delete allow from "$_curipinmanage"
		rm -f "$_userhome/.ipmanage/lastusedip" "$_userhome/.ipmanage/nodel"
  	fi
  fi
fi

if [ "${PAM_TYPE}x" = "open_sessionx" ] && [ -n "$_remoteip" ] ; then

  if [ -f "$_userhome/.ipmanage/lastusedip" ] ; then
  	_ipadd=$(cat "$_userhome/.ipmanage/lastusedip")
  	if [ ! "${_ipadd}x" = "${_remoteip}x" ] && (ufw status | grep -qE "ALLOW.*$_ipadd") ; then
  		ufw delete allow from "$_ipadd"
  	fi
  fi

  echo "$_remoteip" > "$_userhome/.ipmanage/lastusedip"
  if ! (ufw status | grep -qE "ALLOW.*$_remoteip") ; then
  	ufw allow from "$_remoteip"
  fi

fi
