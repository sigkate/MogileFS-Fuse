# Note: this file was auto-generated by Module::Build::Compat version 0.40
use ExtUtils::MakeMaker;
WriteMakefile
(
  'PL_FILES' => {},
  'INSTALLDIRS' => 'site',
  'NAME' => 'MogileFS::Client::Fuse',
  'EXE_FILES' => [
                   'bin/mount-mogilefs'
                 ],
  'VERSION_FROM' => 'lib/MogileFS/Client/Fuse.pm',
  'PREREQ_PM' => {
                   'Test::More' => 0,
                   'Scalar::Util' => 0,
                   'MogileFS::Client::FilePaths' => 0,
                   'Params::Validate' => 0,
                   'Fuse' => '0.11'
                 }
)
;
