# === Class riofs

class riofs () {
	$version='0.3'

	# Download url
	$url = "https://github.com/skoobe/riofs/archive/v${version}.tar.gz"
	# Directory to install in
	$prefix = "/usr/local"
	# Binary path
	$riofs = "${prefix}/bin/riofs"
	# Keep download
	$keep_download = true

	# Install
	include riofs::pkg
	include riofs::exec

}

class riofs::pkg {

	define riofs_install_pkg {
		if ! defined(Package[$name]) {
			package { $name: ensure => present;  }
		}
	}

	$pkg = [
		'autoconf',
		'make',
		'fuse',
		'libtool',
		'pkg-config',
		'libglib2.0-dev',
		'libxml2-dev',
		'libevent-dev',
		'libcrypto++-dev',
		'libfuse-dev',
		'libssl-dev',
		'wget',
		'tar',
		'coreutils',
	]

	riofs_install_pkg { $pkg: ; }
}

class riofs::exec {

	$tmp_dir = "/usr/local/src"
	$tmp_dir_riofs = "${tmp_dir}/riofs-${version}"
	$path = "/bin:/sbin:/usr/bin:/usr/sbin:$tmp_dir_riofs"

	$installed = "test -e ${riofs}"
	$downloaded = "test -e ${tmp_dir_riofs}"

	Exec {
		path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ],
		#unless => "$installed || $downloaded",
	}

	#notify { "Hello": }
	exec { "download":
		cwd => $tmp_dir,
		command => "wget --no-check-certificate -q -O - $url | tar zx",
		unless => "$installed || $downloaded",
		#unless => "$downloaded",
	}

	Exec { 
		cwd => $tmp_dir_riofs,
		unless => $installed,
		#onlyif => $downloaded,
	}

	# !!! -march-native doesnt work on virtual machine, we detect the arch here
	# and fix the configure.ac !!!
	$arch = regsubst($::hardwaremodel,"_","-")
	exec { "configure.ac":
		command => "sed -i 's/-march=native/-march=$arch/' configure.ac",
		require => Exec["download"],
		onlyif => $downloaded,
	}

	exec { "autogen":
		command => "./autogen.sh",
		provider => 'shell',
		require => Exec["configure.ac"],
		onlyif => $downloaded,
	}

	exec { "configure":
		command => "./configure --prefix=${prefix}",
		provider => 'shell',
		require => Exec["autogen"],
		onlyif => $downloaded,
	}

	exec { "make":
		command => "make",
		require => Exec["configure"],
		onlyif => $downloaded,
	}

	exec { "make install":
		command => "make install",
		require => Exec["make"],
		onlyif => $downloaded,
	}

	if (! $keep_download) {

#		exec { "finish install":
#			command => "echo `date +'%F %T'` installed >> $tmp_dir_riofs/puppet.log",
#			require => Exec["make install"],
#			unless => undef,
#		}
#
#	} else {

		exec { "delete download":
			command => "rm -rf $tmp_dir_riofs",
			require => Exec["make install"],
			unless => undef,
			onlyif => $downloaded,
		}

	}

}
