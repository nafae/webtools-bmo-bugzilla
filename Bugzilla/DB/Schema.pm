# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is the Bugzilla Bug Tracking System.
#
# The Initial Developer of the Original Code is Netscape Communications
# Corporation. Portions created by Netscape are
# Copyright (C) 1998 Netscape Communications Corporation. All
# Rights Reserved.
#
# Contributor(s): Andrew Dunstan <andrew@dunslane.net>,
#                 Edward J. Sabol <edwardjsabol@iname.com>

package Bugzilla::DB::Schema;

###########################################################################
#
# Purpose: Object-oriented, DBMS-independent database schema for Bugzilla
#
# This is the base class implementing common methods and abstract schema.
#
###########################################################################

use strict;
use Bugzilla::Error;
use Storable qw(dclone);

=head1 NAME

Bugzilla::DB::Schema - Abstract database schema for Bugzilla

=head1 SYNOPSIS

  # Obtain MySQL database schema.
  # Do not do this. Use Bugzilla::DB instead.
  use Bugzilla::DB::Schema;
  my $mysql_schema = new Bugzilla::DB::Schema('Mysql');

  # Recommended way to obtain database schema.
  use Bugzilla::DB;
  my $dbh = Bugzilla->dbh;
  my $schema = $dbh->_bz_schema();

  # Get the list of tables in the Bugzilla database.
  my @tables = $schema->get_table_list();

  # Get the SQL statements need to create the bugs table.
  my @statements = $schema->get_table_ddl('bugs');

  # Get the database-specific SQL data type used to implement
  # the abstract data type INT1.
  my $db_specific_type = $schema->sql_type('INT1');

=head1 DESCRIPTION

This module implements an object-oriented, abstract database schema.
It should be considered package-private to the Bugzilla::DB module.

=cut
#--------------------------------------------------------------------------
# Define the Bugzilla abstract database schema and version as constants.

=head1 CONSTANTS

=over 4

=item C<SCHEMA_VERSION>

The 'version' of the internal schema structure. This version number
is incremented every time the the fundamental structure of Schema
internals changes. 

This is NOT changed every time a table or a column is added. This 
number is incremented only if the internal structures of this 
Schema would be incompatible with the internal structures of a 
previous Schema version.

=begin undocumented

As a guideline for whether or not to change this version number,
you should think, "Will my changes make this structure fundamentally
incompatible with the old structure?" Think about serialization
of the data structures, because that's what this version number
is used for.

You should RARELY need to increment this version number.

=end undocumented

=item C<ABSTRACT_SCHEMA>

The abstract database schema structure consists of a hash reference
in which each key is the name of a table in the Bugzilla database.
The value for each key is a hash reference containing the keys
C<FIELDS> and C<INDEXES> which in turn point to array references
containing information on the table's fields and indexes. A field
hash reference should must contain the key C<TYPE>. Optional field
keys include C<PRIMARYKEY>, C<NOTNULL>, and C<DEFAULT>. The C<INDEXES>
array reference contains index names and information regarding the
index. If the index name points to an array reference, then the index
is a regular index and the array contains the indexed columns. If the
index name points to a hash reference, then the hash must contain
the key C<FIELDS>. It may also contain the key C<TYPE>, which can be
used to specify the type of index such as UNIQUE or FULLTEXT.

=back

=cut

use constant SCHEMA_VERSION  => '1.00';
use constant ABSTRACT_SCHEMA => {

    # BUG-RELATED TABLES
    # ------------------

    # General Bug Information
    # -----------------------
    bugs => {
        FIELDS => [
            bug_id              => {TYPE => 'MEDIUMSERIAL', NOTNULL => 1,
                                    PRIMARYKEY => 1},
            assigned_to         => {TYPE => 'INT3', NOTNULL => 1},
            bug_file_loc        => {TYPE => 'TEXT'},
            bug_severity        => {TYPE => 'varchar(64)', NOTNULL => 1},
            bug_status          => {TYPE => 'varchar(64)', NOTNULL => 1},
            creation_ts         => {TYPE => 'DATETIME', NOTNULL => 1},
            delta_ts            => {TYPE => 'DATETIME', NOTNULL => 1},
            short_desc          => {TYPE => 'MEDIUMTEXT', NOTNULL => 1},
            op_sys              => {TYPE => 'varchar(64)', NOTNULL => 1},
            priority            => {TYPE => 'varchar(64)', NOTNULL => 1},
            product_id          => {TYPE => 'INT2', NOTNULL => 1},
            rep_platform        => {TYPE => 'varchar(64)', NOTNULL => 1},
            reporter            => {TYPE => 'INT3', NOTNULL => 1},
            version             => {TYPE => 'varchar(64)', NOTNULL => 1},
            component_id        => {TYPE => 'INT2', NOTNULL => 1},
            resolution          => {TYPE => 'varchar(64)', NOTNULL => 1},
            target_milestone    => {TYPE => 'varchar(20)',
                                    NOTNULL => 1, DEFAULT => "'---'"},
            qa_contact          => {TYPE => 'INT3', NOTNULL => 1},
            status_whiteboard   => {TYPE => 'MEDIUMTEXT', NOTNULL => 1},
            votes               => {TYPE => 'INT3', NOTNULL => 1},
            # Note: keywords field is only a cache; the real data
            # comes from the keywords table
            keywords            => {TYPE => 'MEDIUMTEXT', NOTNULL => 1},
            lastdiffed          => {TYPE => 'DATETIME', NOTNULL => 1},
            everconfirmed       => {TYPE => 'BOOLEAN', NOTNULL => 1},
            reporter_accessible => {TYPE => 'BOOLEAN',
                                    NOTNULL => 1, DEFAULT => 'TRUE'},
            cclist_accessible   => {TYPE => 'BOOLEAN',
                                    NOTNULL => 1, DEFAULT => 'TRUE'},
            estimated_time      => {TYPE => 'decimal(5,2)',
                                    NOTNULL => 1, DEFAULT => '0'},
            remaining_time      => {TYPE => 'decimal(5,2)',
                                    NOTNULL => 1, DEFAULT => '0'},
            deadline            => {TYPE => 'DATETIME'},
            alias               => {TYPE => 'varchar(20)'},
        ],
        INDEXES => [
            bugs_unique_idx           => {FIELDS => ['alias'],
                                          TYPE => 'UNIQUE'},
            bugs_assigned_to_idx      => ['assigned_to'],
            bugs_creation_ts_idx      => ['creation_ts'],
            bugs_delta_ts_idx         => ['delta_ts'],
            bugs_bug_severity_idx     => ['bug_severity'],
            bugs_bug_status_idx       => ['bug_status'],
            bugs_op_sys_idx           => ['op_sys'],
            bugs_priority_idx         => ['priority'],
            bugs_product_id_idx       => ['product_id'],
            bugs_reporter_idx         => ['reporter'],
            bugs_version_idx          => ['version'],
            bugs_component_id_idx     => ['component_id'],
            bugs_resolution_idx       => ['resolution'],
            bugs_target_milestone_idx => ['target_milestone'],
            bugs_qa_contact_idx       => ['qa_contact'],
            bugs_votes_idx            => ['votes'],
            bugs_short_desc_idx       => {FIELDS => ['short_desc'],
                                          TYPE => 'FULLTEXT'},
        ],
    },

    bugs_activity => {
        FIELDS => [
            bug_id    => {TYPE => 'INT3', NOTNULL => 1},
            attach_id => {TYPE => 'INT3'},
            who       => {TYPE => 'INT3', NOTNULL => 1},
            bug_when  => {TYPE => 'DATETIME', NOTNULL => 1},
            fieldid   => {TYPE => 'INT3', NOTNULL => 1},
            added     => {TYPE => 'TINYTEXT'},
            removed   => {TYPE => 'TINYTEXT'},
        ],
        INDEXES => [
            bugs_activity_bugid_idx   => ['bug_id'],
            bugs_activity_who_idx     => ['who'],
            bugs_activity_bugwhen_idx => ['bug_when'],
            bugs_activity_fieldid_idx => ['fieldid'],
        ],
    },

    cc => {
        FIELDS => [
            bug_id => {TYPE => 'INT3', NOTNULL => 1},
            who    => {TYPE => 'INT3', NOTNULL => 1},
        ],
        INDEXES => [
            cc_unique_idx => {FIELDS => [qw(bug_id who)],
                              TYPE => 'UNIQUE'},
            cc_who_idx    => ['who'],
        ],
    },

    longdescs => {
        FIELDS => [
            bug_id          => {TYPE => 'INT3',  NOTNULL => 1},
            who             => {TYPE => 'INT3', NOTNULL => 1},
            bug_when        => {TYPE => 'DATETIME', NOTNULL => 1},
            work_time       => {TYPE => 'decimal(5,2)', NOTNULL => 1,
                                DEFAULT => '0'},
            thetext         => {TYPE => 'MEDIUMTEXT'},
            isprivate       => {TYPE => 'BOOLEAN', NOTNULL => 1,
                                DEFAULT => 'FALSE'},
            already_wrapped => {TYPE => 'BOOLEAN', NOTNULL => 1,
                                DEFAULT => 'FALSE'},
        ],
        INDEXES => [
            longdescs_bugid_idx   => ['bug_id'],
            longdescs_who_idx     => ['who'],
            longdescs_bugwhen_idx => ['bug_when'],
            longdescs_thetext_idx => {FIELDS => ['thetext'],
                                      TYPE => 'FULLTEXT'},
        ],
    },

    dependencies => {
        FIELDS => [
            blocked   => {TYPE => 'INT3', NOTNULL => 1},
            dependson => {TYPE => 'INT3', NOTNULL => 1},
        ],
        INDEXES => [
            dependencies_blocked_idx   => ['blocked'],
            dependencies_dependson_idx => ['dependson'],
        ],
    },

    votes => {
        FIELDS => [
            who        => {TYPE => 'INT3', NOTNULL => 1},
            bug_id     => {TYPE => 'INT3', NOTNULL => 1},
            vote_count => {TYPE => 'INT2', NOTNULL => 1},
        ],
        INDEXES => [
            votes_who_idx    => ['who'],
            votes_bug_id_idx => ['bug_id'],
        ],
    },

    attachments => {
        FIELDS => [
            attach_id    => {TYPE => 'MEDIUMSERIAL', NOTNULL => 1,
                             PRIMARYKEY => 1},
            bug_id       => {TYPE => 'INT3', NOTNULL => 1},
            creation_ts  => {TYPE => 'DATETIME', NOTNULL => 1},
            description  => {TYPE => 'MEDIUMTEXT', NOTNULL => 1},
            mimetype     => {TYPE => 'MEDIUMTEXT', NOTNULL => 1},
            ispatch      => {TYPE => 'BOOLEAN'},
            filename     => {TYPE => 'varchar(100)', NOTNULL => 1},
            thedata      => {TYPE => 'LONGBLOB', NOTNULL => 1},
            submitter_id => {TYPE => 'INT3', NOTNULL => 1},
            isobsolete   => {TYPE => 'BOOLEAN', NOTNULL => 1,
                             DEFAULT => 'FALSE'},
            isprivate    => {TYPE => 'BOOLEAN', NOTNULL => 1,
                             DEFAULT => 'FALSE'},
        ],
        INDEXES => [
            attachments_bug_id_idx => ['bug_id'],
            attachments_creation_ts_idx => ['creation_ts'],
        ],
    },

    duplicates => {
        FIELDS => [
            dup_of => {TYPE => 'INT3', NOTNULL => 1},
            dup    => {TYPE => 'INT3', NOTNULL => 1,
                       PRIMARYKEY => 1},
        ],
    },

    # Keywords
    # --------

    keyworddefs => {
        FIELDS => [
            id          => {TYPE => 'INT2', NOTNULL => 1,
                            PRIMARYKEY => 1},
            name        => {TYPE => 'varchar(64)', NOTNULL => 1},
            description => {TYPE => 'MEDIUMTEXT'},
        ],
        INDEXES => [
            keyworddefs_unique_idx => {FIELDS => ['name'],
                                       TYPE => 'UNIQUE'},
        ],
    },

    keywords => {
        FIELDS => [
            bug_id    => {TYPE => 'INT3', NOTNULL => 1},
            keywordid => {TYPE => 'INT2', NOTNULL => 1},
        ],
        INDEXES => [
            keywords_unique_idx    => {FIELDS => [qw(bug_id keywordid)],
                                       TYPE => 'UNIQUE'},
            keywords_keywordid_idx => ['keywordid'],
        ],
    },

    # Flags
    # -----

    # "flags" stores one record for each flag on each bug/attachment.
    flags => {
        FIELDS => [
            id                => {TYPE => 'INT3', NOTNULL => 1,
                                  PRIMARYKEY => 1},
            type_id           => {TYPE => 'INT2', NOTNULL => 1},
            status            => {TYPE => 'char(1)', NOTNULL => 1},
            bug_id            => {TYPE => 'INT3', NOTNULL => 1},
            attach_id         => {TYPE => 'INT3'},
            creation_date     => {TYPE => 'DATETIME', NOTNULL => 1},
            modification_date => {TYPE => 'DATETIME'},
            setter_id         => {TYPE => 'INT3'},
            requestee_id      => {TYPE => 'INT3'},
            is_active         => {TYPE => 'BOOLEAN', NOTNULL => 1,
                                  DEFAULT => 'TRUE'},
        ],
        INDEXES => [
            flags_bidattid_idx     => [qw(bug_id attach_id)],
            flags_setter_id_idx    => ['setter_id'],
            flags_requestee_id_idx => ['requestee_id'],
        ],
    },

    # "flagtypes" defines the types of flags that can be set.
    flagtypes => {
        FIELDS => [
            id               => {TYPE => 'INT2', NOTNULL => 1,
                                 PRIMARYKEY => 1},
            name             => {TYPE => 'varchar(50)', NOTNULL => 1},
            description      => {TYPE => 'TEXT'},
            cc_list          => {TYPE => 'varchar(200)'},
            target_type      => {TYPE => 'char(1)', NOTNULL => 1,
                                 DEFAULT => "'b'"},
            is_active        => {TYPE => 'BOOLEAN', NOTNULL => 1,
                                 DEFAULT => 'TRUE'},
            is_requestable   => {TYPE => 'BOOLEAN', NOTNULL => 1,
                                 DEFAULT => 'FALSE'},
            is_requesteeble  => {TYPE => 'BOOLEAN', NOTNULL => 1,
                                 DEFAULT => 'FALSE'},
            is_multiplicable => {TYPE => 'BOOLEAN', NOTNULL => 1,
                                 DEFAULT => 'FALSE'},
            sortkey          => {TYPE => 'INT2', NOTNULL => 1,
                                 DEFAULT => '0'},
            grant_group_id   => {TYPE => 'INT3'},
            request_group_id => {TYPE => 'INT3'},
        ],
    },

    # "flaginclusions" and "flagexclusions" specify the products/components
    #     a bug/attachment must belong to in order for flags of a given type
    #     to be set for them.
    flaginclusions => {
        FIELDS => [
            type_id      => {TYPE => 'INT2', NOTNULL => 1},
            product_id   => {TYPE => 'INT2'},
            component_id => {TYPE => 'INT2'},
        ],
        INDEXES => [
            flaginclusions_tpcid_idx =>
                [qw(type_id product_id component_id)],
        ],
    },

    flagexclusions => {
        FIELDS => [
            type_id      => {TYPE => 'INT2', NOTNULL => 1},
            product_id   => {TYPE => 'INT2'},
            component_id => {TYPE => 'INT2'},
        ],
        INDEXES => [
            flagexclusions_tpc_id_idx =>
                [qw(type_id product_id component_id)],
        ],
    },

    # General Field Information
    # -------------------------

    fielddefs => {
        FIELDS => [
            fieldid     => {TYPE => 'MEDIUMSERIAL', NOTNULL => 1,
                            PRIMARYKEY => 1},
            name        => {TYPE => 'varchar(64)', NOTNULL => 1},
            description => {TYPE => 'MEDIUMTEXT', NOTNULL => 1},
            mailhead    => {TYPE => 'BOOLEAN', NOTNULL => 1,
                            DEFAULT => 'FALSE'},
            sortkey     => {TYPE => 'INT2', NOTNULL => 1},
            obsolete    => {TYPE => 'BOOLEAN', NOTNULL => 1,
                            DEFAULT => 'FALSE'},
        ],
        INDEXES => [
            fielddefs_unique_idx  => {FIELDS => ['name'],
                                      TYPE => 'UNIQUE'},
            fielddefs_sortkey_idx => ['sortkey'],
        ],
    },

    # Per-product Field Values
    # ------------------------

    versions => {
        FIELDS => [
            value      =>  {TYPE => 'TINYTEXT'},
            product_id =>  {TYPE => 'INT2', NOTNULL => 1},
        ],
    },

    milestones => {
        FIELDS => [
            product_id => {TYPE => 'INT2', NOTNULL => 1},
            value      => {TYPE => 'varchar(20)', NOTNULL => 1},
            sortkey    => {TYPE => 'INT2', NOTNULL => 1},
        ],
        INDEXES => [
            milestones_unique_idx => {FIELDS => [qw(product_id value)],
                                      TYPE => 'UNIQUE'},
        ],
    },

    # Global Field Values
    # -------------------

    bug_status => {
        FIELDS => [
            id       => {TYPE => 'SMALLSERIAL', NOTNULL => 1,
                         PRIMARYKEY => 1},
            value    => {TYPE => 'varchar(64)', NOTNULL => 1},
            sortkey  => {TYPE => 'INT2', NOTNULL => 1, DEFAULT => 0},
            isactive => {TYPE => 'BOOLEAN', NOTNULL => 1, 
                         DEFAULT => 'TRUE'},
        ],
        INDEXES => [
            bug_status_unique_idx  => {FIELDS => ['value'],
                                       TYPE => 'UNIQUE'},
            bug_status_sortkey_idx => ['sortkey', 'value'],
        ],
    },

    resolution => {
        FIELDS => [
            id       => {TYPE => 'SMALLSERIAL', NOTNULL => 1,
                         PRIMARYKEY => 1},
            value    => {TYPE => 'varchar(64)', NOTNULL => 1},
            sortkey  => {TYPE => 'INT2', NOTNULL => 1, DEFAULT => 0},
            isactive => {TYPE => 'BOOLEAN', NOTNULL => 1, 
                         DEFAULT => 'TRUE'},
        ],
        INDEXES => [
            resolution_unique_idx  => {FIELDS => ['value'],
                                       TYPE => 'UNIQUE'},
            resolution_sortkey_idx => ['sortkey', 'value'],
        ],
    },

    bug_severity => {
        FIELDS => [
            id       => {TYPE => 'SMALLSERIAL', NOTNULL => 1, 
                         PRIMARYKEY => 1},
            value    => {TYPE => 'varchar(64)', NOTNULL => 1},
            sortkey  => {TYPE => 'INT2', NOTNULL => 1, DEFAULT => 0},
            isactive => {TYPE => 'BOOLEAN', NOTNULL => 1, 
                         DEFAULT => 'TRUE'},
        ],
        INDEXES => [
            bug_severity_unique_idx  => {FIELDS => ['value'],
                                         TYPE => 'UNIQUE'},
            bug_severity_sortkey_idx => ['sortkey', 'value'],
        ],
    },

    priority => {
        FIELDS => [
            id       => {TYPE => 'SMALLSERIAL', NOTNULL => 1,
                         PRIMARYKEY => 1},
            value    => {TYPE => 'varchar(64)', NOTNULL => 1},
            sortkey  => {TYPE => 'INT2', NOTNULL => 1, DEFAULT => 0},
            isactive => {TYPE => 'BOOLEAN', NOTNULL => 1, 
                         DEFAULT => 'TRUE'},
        ],
        INDEXES => [
            priority_unique_idx  => {FIELDS => ['value'],
                                     TYPE => 'UNIQUE'},
            priority_sortkey_idx => ['sortkey', 'value'],
        ],
    },

    rep_platform => {
        FIELDS => [
            id       => {TYPE => 'SMALLSERIAL', NOTNULL => 1,
                         PRIMARYKEY => 1},
            value    => {TYPE => 'varchar(64)', NOTNULL => 1},
            sortkey  => {TYPE => 'INT2', NOTNULL => 1, DEFAULT => 0},
            isactive => {TYPE => 'BOOLEAN', NOTNULL => 1, 
                         DEFAULT => 'TRUE'},
        ],
        INDEXES => [
            rep_platform_unique_idx  => {FIELDS => ['value'],
                                         TYPE => 'UNIQUE'},
            rep_platform_sortkey_idx => ['sortkey', 'value'],
        ],
    },

    op_sys => {
        FIELDS => [
            id       => {TYPE => 'SMALLSERIAL', NOTNULL => 1,
                         PRIMARYKEY => 1},
            value    => {TYPE => 'varchar(64)', NOTNULL => 1},
            sortkey  => {TYPE => 'INT2', NOTNULL => 1, DEFAULT => 0},
            isactive => {TYPE => 'BOOLEAN', NOTNULL => 1, 
                         DEFAULT => 'TRUE'},
        ],
        INDEXES => [
            op_sys_unique_idx  => {FIELDS => ['value'],
                                   TYPE => 'UNIQUE'},
            op_sys_sortkey_idx => ['sortkey', 'value'],
        ],
    },

    # USER INFO
    # ---------

    # General User Information
    # ------------------------

    profiles => {
        FIELDS => [
            userid         => {TYPE => 'MEDIUMSERIAL', NOTNULL => 1,
                               PRIMARYKEY => 1},
            login_name     => {TYPE => 'varchar(255)', NOTNULL => 1},
            cryptpassword  => {TYPE => 'varchar(128)'},
            realname       => {TYPE => 'varchar(255)'},
            disabledtext   => {TYPE => 'MEDIUMTEXT', NOTNULL => 1},
            mybugslink     => {TYPE => 'BOOLEAN', NOTNULL => 1,
                               DEFAULT => 'TRUE'},
            emailflags     => {TYPE => 'MEDIUMTEXT'},
            refreshed_when => {TYPE => 'DATETIME', NOTNULL => 1},
            extern_id      => {TYPE => 'varchar(64)'},
        ],
        INDEXES => [
            profiles_unique_idx => {FIELDS => ['login_name'],
                                    TYPE => 'UNIQUE'},
        ],
    },

    profiles_activity => {
        FIELDS => [
            userid        => {TYPE => 'INT3', NOTNULL => 1},
            who           => {TYPE => 'INT3', NOTNULL => 1},
            profiles_when => {TYPE => 'DATETIME', NOTNULL => 1},
            fieldid       => {TYPE => 'INT3', NOTNULL => 1},
            oldvalue      => {TYPE => 'TINYTEXT'},
            newvalue      => {TYPE => 'TINYTEXT'},
        ],
        INDEXES => [
            profiles_activity_userid_idx  => ['userid'],
            profiles_activity_when_idx    => ['profiles_when'],
            profiles_activity_fieldid_idx => ['fieldid'],
        ],
    },

    watch => {
        FIELDS => [
            watcher => {TYPE => 'INT3', NOTNULL => 1},
            watched => {TYPE => 'INT3', NOTNULL => 1},
        ],
        INDEXES => [
            watch_unique_idx  => {FIELDS => [qw(watcher watched)],
                                  TYPE => 'UNIQUE'},
            watch_watched_idx => ['watched'],
        ],
    },

    namedqueries => {
        FIELDS => [
            userid       => {TYPE => 'INT3', NOTNULL => 1},
            name         => {TYPE => 'varchar(64)', NOTNULL => 1},
            linkinfooter => {TYPE => 'BOOLEAN', NOTNULL => 1},
            query        => {TYPE => 'MEDIUMTEXT', NOTNULL => 1},
        ],
        INDEXES => [
            namedqueries_unique_idx => {FIELDS => [qw(userid name)],
                                        TYPE => 'UNIQUE'},
        ],
    },

    # Authentication
    # --------------

    logincookies => {
        FIELDS => [
            cookie   => {TYPE => 'MEDIUMSERIAL', NOTNULL => 1,
                         PRIMARYKEY => 1},
            userid   => {TYPE => 'INT3', NOTNULL => 1},
            ipaddr   => {TYPE => 'varchar(40)', NOTNULL => 1},
            lastused => {TYPE => 'DATETIME', NOTNULL => 1},
        ],
        INDEXES => [
            logincookies_lastused_idx => ['lastused'],
        ],
    },

    # "tokens" stores the tokens users receive when a password or email
    #     change is requested.  Tokens provide an extra measure of security
    #     for these changes.
    tokens => {
        FIELDS => [
            userid    => {TYPE => 'INT3', NOTNULL => 1} ,
            issuedate => {TYPE => 'DATETIME', NOTNULL => 1} ,
            token     => {TYPE => 'varchar(16)', NOTNULL => 1,
                          PRIMARYKEY => 1},
            tokentype => {TYPE => 'varchar(8)', NOTNULL => 1} ,
            eventdata => {TYPE => 'TINYTEXT'},
        ],
        INDEXES => [
            tokens_userid_idx => ['userid'],
        ],
    },

    # GROUPS
    # ------

    groups => {
        FIELDS => [
            id           => {TYPE => 'MEDIUMSERIAL', NOTNULL => 1,
                             PRIMARYKEY => 1},
            name         => {TYPE => 'varchar(255)', NOTNULL => 1},
            description  => {TYPE => 'TEXT', NOTNULL => 1},
            isbuggroup   => {TYPE => 'BOOLEAN', NOTNULL => 1},
            last_changed => {TYPE => 'DATETIME', NOTNULL => 1},
            userregexp   => {TYPE => 'TINYTEXT', NOTNULL => 1},
            isactive     => {TYPE => 'BOOLEAN', NOTNULL => 1,
                             DEFAULT => 'TRUE'},
        ],
        INDEXES => [
            groups_unique_idx => {FIELDS => ['name'], TYPE => 'UNIQUE'},
        ],
    },

    group_control_map => {
        FIELDS => [
            group_id      => {TYPE => 'INT3', NOTNULL => 1},
            product_id    => {TYPE => 'INT3', NOTNULL => 1},
            entry         => {TYPE => 'BOOLEAN', NOTNULL => 1},
            membercontrol => {TYPE => 'BOOLEAN', NOTNULL => 1},
            othercontrol  => {TYPE => 'BOOLEAN', NOTNULL => 1},
            canedit       => {TYPE => 'BOOLEAN', NOTNULL => 1},
        ],
        INDEXES => [
            group_control_map_unique_idx =>
            {FIELDS => [qw(product_id group_id)], TYPE => 'UNIQUE'},
            group_control_map_gid_idx    => ['group_id'],
        ],
    },

    # "user_group_map" determines the groups that a user belongs to
    # directly or due to regexp and which groups can be blessed by a user.
    #
    # grant_type:
    # if GRANT_DIRECT - record was explicitly granted
    # if GRANT_DERIVED - record was derived from expanding a group hierarchy
    # if GRANT_REGEXP - record was created by evaluating a regexp
    user_group_map => {
        FIELDS => [
            user_id    => {TYPE => 'INT3', NOTNULL => 1},
            group_id   => {TYPE => 'INT3', NOTNULL => 1},
            isbless    => {TYPE => 'BOOLEAN', NOTNULL => 1,
                           DEFAULT => 'FALSE'},
            grant_type => {TYPE => 'INT1', NOTNULL => 1,
                           DEFAULT => '0'},
        ],
        INDEXES => [
            user_group_map_unique_idx =>
                {FIELDS => [qw(user_id group_id grant_type isbless)],
                 TYPE => 'UNIQUE'},
        ],
    },

    # This table determines which groups are made a member of another
    # group, given the ability to bless another group, or given
    # visibility to another groups existence and membership
    # grant_type:
    # if GROUP_MEMBERSHIP - member groups are made members of grantor
    # if GROUP_BLESS - member groups may grant membership in grantor
    # if GROUP_VISIBLE - member groups may see grantor group
    group_group_map => {
        FIELDS => [
            member_id  => {TYPE => 'INT3', NOTNULL => 1},
            grantor_id => {TYPE => 'INT3', NOTNULL => 1},
            grant_type => {TYPE => 'INT1', NOTNULL => 1,
                           DEFAULT => '0'},
        ],
        INDEXES => [
            group_group_map_unique_idx =>
                {FIELDS => [qw(member_id grantor_id grant_type)],
                 TYPE => 'UNIQUE'},
        ],
    },

    # This table determines which groups a user must be a member of
    # in order to see a bug.
    bug_group_map => {
        FIELDS => [
            bug_id   => {TYPE => 'INT3', NOTNULL => 1},
            group_id => {TYPE => 'INT3', NOTNULL => 1},
        ],
        INDEXES => [
            bug_group_map_unique_idx   =>
                {FIELDS => [qw(bug_id group_id)], TYPE => 'UNIQUE'},
            bug_group_map_group_id_idx => ['group_id'],
        ],
    },

    category_group_map => {
        FIELDS => [
            category_id => {TYPE => 'INT2', NOTNULL => 1},
            group_id    => {TYPE => 'INT3', NOTNULL => 1},
        ],
        INDEXES => [
            category_group_map_unique_idx =>
                {FIELDS => [qw(category_id group_id)], TYPE => 'UNIQUE'},
        ],
    },


    # PRODUCTS
    # --------

    classifications => {
        FIELDS => [
            id          => {TYPE => 'SMALLSERIAL', NOTNULL => 1,
                            PRIMARYKEY => 1},
            name        => {TYPE => 'varchar(64)', NOTNULL => 1},
            description => {TYPE => 'MEDIUMTEXT'},
        ],
        INDEXES => [
            classifications_unique_idx => {FIELDS => ['name'],
                                           TYPE => 'UNIQUE'},
        ],
    },

    products => {
        FIELDS => [
            id                => {TYPE => 'SMALLSERIAL', NOTNULL => 1,
                                  PRIMARYKEY => 1},
            name              => {TYPE => 'varchar(64)', NOTNULL => 1},
            classification_id => {TYPE => 'INT2', NOTNULL => 1,
                                  DEFAULT => '1'},
            description       => {TYPE => 'MEDIUMTEXT'},
            milestoneurl      => {TYPE => 'TINYTEXT', NOTNULL => 1},
            disallownew       => {TYPE => 'BOOLEAN', NOTNULL => 1},
            votesperuser      => {TYPE => 'INT2', NOTNULL => 1},
            maxvotesperbug    => {TYPE => 'INT2', NOTNULL => 1,
                                  DEFAULT => '10000'},
            votestoconfirm    => {TYPE => 'INT2', NOTNULL => 1},
            defaultmilestone  => {TYPE => 'varchar(20)',
                                  NOTNULL => 1, DEFAULT => "'---'"},
        ],
        INDEXES => [
            products_unique_idx => {FIELDS => ['name'],
                                    TYPE => 'UNIQUE'},
        ],
    },

    components => {
        FIELDS => [
            id               => {TYPE => 'SMALLSERIAL', NOTNULL => 1,
                                 PRIMARYKEY => 1},
            name             => {TYPE => 'varchar(64)', NOTNULL => 1},
            product_id       => {TYPE => 'INT2', NOTNULL => 1},
            initialowner     => {TYPE => 'INT3'},
            initialqacontact => {TYPE => 'INT3'},
            description      => {TYPE => 'MEDIUMTEXT', NOTNULL => 1},
        ],
        INDEXES => [
            components_unique_idx => {FIELDS => [qw(product_id name)],
                                      TYPE => 'UNIQUE'},
            components_name_idx   => ['name'],
        ],
    },

    # CHARTS
    # ------

    series => {
        FIELDS => [
            series_id   => {TYPE => 'MEDIUMSERIAL', NOTNULL => 1,
                            PRIMARYKEY => 1},
            creator     => {TYPE => 'INT3', NOTNULL => 1},
            category    => {TYPE => 'INT2', NOTNULL => 1},
            subcategory => {TYPE => 'INT2', NOTNULL => 1},
            name        => {TYPE => 'varchar(64)', NOTNULL => 1},
            frequency   => {TYPE => 'INT2', NOTNULL => 1},
            last_viewed => {TYPE => 'DATETIME'},
            query       => {TYPE => 'MEDIUMTEXT', NOTNULL => 1},
            public      => {TYPE => 'BOOLEAN', NOTNULL => 1,
                            DEFAULT => 'FALSE'},
        ],
        INDEXES => [
            series_unique_idx  =>
                {FIELDS => [qw(creator category subcategory name)],
                 TYPE => 'UNIQUE'},
            series_creator_idx => ['creator'],
        ],
    },

    series_data => {
        FIELDS => [
            series_id    => {TYPE => 'INT3', NOTNULL => 1},
            series_date  => {TYPE => 'DATETIME', NOTNULL => 1},
            series_value => {TYPE => 'INT3', NOTNULL => 1},
        ],
        INDEXES => [
            series_data_unique_idx =>
                {FIELDS => [qw(series_id series_date)],
                 TYPE => 'UNIQUE'},
        ],
    },

    series_categories => {
        FIELDS => [
            id   => {TYPE => 'SMALLSERIAL', NOTNULL => 1,
                     PRIMARYKEY => 1},
            name => {TYPE => 'varchar(64)', NOTNULL => 1},
        ],
        INDEXES => [
            series_cats_unique_idx => {FIELDS => ['name'],
                                       TYPE => 'UNIQUE'},
        ],
    },

    # WHINE SYSTEM
    # ------------

    whine_queries => {
        FIELDS => [
            id            => {TYPE => 'MEDIUMSERIAL', PRIMARYKEY => 1},
            eventid       => {TYPE => 'INT3', NOTNULL => 1},
            query_name    => {TYPE => 'varchar(64)', NOTNULL => 1,
                              DEFAULT => "''"},
            sortkey       => {TYPE => 'INT2', NOTNULL => 1,
                              DEFAULT => '0'},
            onemailperbug => {TYPE => 'BOOLEAN', NOTNULL => 1,
                              DEFAULT => 'FALSE'},
            title         => {TYPE => 'varchar(128)', NOTNULL => 1},
        ],
        INDEXES => [
            whine_queries_eventid_idx => ['eventid'],
        ],
    },

    whine_schedules => {
        FIELDS => [
            id          => {TYPE => 'MEDIUMSERIAL', PRIMARYKEY => 1},
            eventid     => {TYPE => 'INT3', NOTNULL => 1},
            run_day     => {TYPE => 'varchar(32)'},
            run_time    => {TYPE => 'varchar(32)'},
            run_next    => {TYPE => 'DATETIME'},
            mailto      => {TYPE => 'INT3', NOTNULL => 1},
            mailto_type => {TYPE => 'INT2', NOTNULL => 1, DEFAULT => '0'},
        ],
        INDEXES => [
            whine_schedules_run_next_idx => ['run_next'],
            whine_schedules_eventid_idx  => ['eventid'],
        ],
    },

    whine_events => {
        FIELDS => [
            id           => {TYPE => 'MEDIUMSERIAL', PRIMARYKEY => 1},
            owner_userid => {TYPE => 'INT3', NOTNULL => 1},
            subject      => {TYPE => 'varchar(128)'},
            body         => {TYPE => 'MEDIUMTEXT'},
        ],
    },

    # QUIPS
    # -----

    quips => {
        FIELDS => [
            quipid   => {TYPE => 'MEDIUMSERIAL', NOTNULL => 1,
                         PRIMARYKEY => 1},
            userid   => {TYPE => 'INT3'},
            quip     => {TYPE => 'TEXT', NOTNULL => 1},
            approved => {TYPE => 'BOOLEAN', NOTNULL => 1,
                         DEFAULT => 'TRUE'},
        ],
    },

};
#--------------------------------------------------------------------------

=head1 METHODS

Note: Methods which can be implemented generically for all DBs are
implemented in this module. If needed, they can be overriden with
DB-specific code in a subclass. Methods which are prefixed with C<_>
are considered protected. Subclasses may override these methods, but
other modules should not invoke these methods directly.

=over 4

=cut

#--------------------------------------------------------------------------
sub new {

=item C<new>

 Description: Public constructor method used to instantiate objects of this
              class. However, it also can be used as a factory method to
              instantiate database-specific subclasses when an optional
              driver argument is supplied.
 Parameters:  $driver (optional) - Used to specify the type of database.
              This routine C<die>s if no subclass is found for the specified
              driver.
 Returns:     new instance of the Schema class or a database-specific subclass

=cut

    my $this = shift;
    my $class = ref($this) || $this;
    my $driver = shift;

    if ($driver) {
        (my $subclass = $driver) =~ s/^(\S)/\U$1/;
        $class .= '::' . $subclass;
        eval "require $class;";
        die "The $class class could not be found ($subclass " .
            "not supported?): $@" if ($@);
    }
    die "$class is an abstract base class. Instantiate a subclass instead."
      if ($class eq __PACKAGE__);

    my $self = {};
    bless $self, $class;
    $self = $self->_initialize(@_);

    return($self);

} #eosub--new
#--------------------------------------------------------------------------
sub _initialize {

=item C<_initialize>

 Description: Protected method that initializes an object after
              instantiation with the abstract schema. All subclasses should
              override this method. The typical subclass implementation
              should first call the C<_initialize> method of the superclass,
              then do any database-specific initialization (especially
              define the database-specific implementation of the all
              abstract data types), and then call the C<_adjust_schema>
              method.
 Parameters:  none
 Returns:     the instance of the Schema class

=cut

    my $self = shift;

    $self->{schema} = dclone(ABSTRACT_SCHEMA);
    $self->{abstract_schema} = ABSTRACT_SCHEMA;

    return $self;

} #eosub--_initialize
#--------------------------------------------------------------------------
sub _adjust_schema {

=item C<_adjust_schema>

 Description: Protected method that alters the abstract schema at
              instantiation-time to be database-specific. It is a generic
              enough routine that it can be defined here in the base class.
              It takes the abstract schema and replaces the abstract data
              types with database-specific data types.
 Parameters:  none
 Returns:     the instance of the Schema class

=cut

    my $self = shift;

    # The _initialize method has already set up the db_specific hash with
    # the information on how to implement the abstract data types for the
    # instantiated DBMS-specific subclass.
    my $db_specific = $self->{db_specific};

    # Loop over each table in the abstract database schema.
    foreach my $table (keys %{ $self->{schema} }) {
        my %fields = (@{ $self->{schema}{$table}{FIELDS} });
        # Loop over the field defintions in each table.
        foreach my $field_def (values %fields) {
            # If the field type is an abstract data type defined in the
            # $db_specific hash, replace it with the DBMS-specific data type
            # that implements it.
            if (exists($db_specific->{$field_def->{TYPE}})) {
                $field_def->{TYPE} = $db_specific->{$field_def->{TYPE}};
            }
            # Replace abstract default values (such as 'TRUE' and 'FALSE')
            # with their database-specific implementations.
            if (exists($field_def->{DEFAULT})
                && exists($db_specific->{$field_def->{DEFAULT}})) {
                $field_def->{DEFAULT} = $db_specific->{$field_def->{DEFAULT}};
            }
        }
    }

    return $self;

} #eosub--_adjust_schema
#--------------------------------------------------------------------------
sub get_type_ddl {

=item C<get_type_ddl>

 Description: Public method to convert abstract (database-generic) field
              specifiers to database-specific data types suitable for use
              in a C<CREATE TABLE> or C<ALTER TABLE> SQL statment. If no
              database-specific field type has been defined for the given
              field type, then it will just return the same field type.
 Parameters:  a hash or a reference to a hash of a field containing the
              following keys: C<TYPE> (required), C<NOTNULL> (optional),
              C<DEFAULT> (optional), C<PRIMARYKEY> (optional), C<REFERENCES>
              (optional)
 Returns:     a DDL string suitable for describing a field in a
              C<CREATE TABLE> or C<ALTER TABLE> SQL statement

=cut

    my $self = shift;
    my $finfo = (@_ == 1 && ref($_[0]) eq 'HASH') ? $_[0] : { @_ };

    my $type = $finfo->{TYPE};
    die "A valid TYPE was not specified for this column." unless ($type);
    my $default = $finfo->{DEFAULT};
    my $fkref = $self->{enable_references} ? $finfo->{REFERENCES} : undef;
    my $type_ddl = $self->{db_specific}{$type} || $type;
    $type_ddl .= " NOT NULL" if ($finfo->{NOTNULL});
    $type_ddl .= " DEFAULT $default" if (defined($default));
    $type_ddl .= " PRIMARY KEY" if ($finfo->{PRIMARYKEY});
    $type_ddl .= "\n\t\t\t\tREFERENCES $fkref" if $fkref;

    return($type_ddl);

} #eosub--get_type_ddl
#--------------------------------------------------------------------------
sub get_column_info {

=item C<get_column_info>

 Description: Public method to generate a DDL segment of a "create table"
              SQL statement for a given table and field.
 Parameters:  $table - the table name
              $column - a column in the table
 Returns:     a hash containing information about the column including its
              type (C<TYPE>), whether or not it can be null (C<NOTNULL>),
              its default value if it has one (C<DEFAULT), whether it is
              a etc. The hash will be empty if either the specified
              table or column does not exist in the database schema.

=cut

    my($self, $table, $column) = @_;

    my $thash = $self->{schema}{$table};
    return() unless ($thash);

    my %fields = @{ $thash->{FIELDS} };
    return() unless ($fields{$column});
    return %{ $fields{$column} };

} #eosub--get_column_info
#--------------------------------------------------------------------------
sub get_table_list {

=item C<get_table_list>

 Description: Public method for discovering what tables should exist in the
              Bugzilla database.
 Parameters:  none
 Returns:     an array of table names

=cut

    my $self = shift;

    return(sort(keys %{ $self->{schema} }));

} #eosub--get_table_list
#--------------------------------------------------------------------------
sub get_table_columns {

=item C<get_table_columns>

 Description: Public method for discovering what columns are in a given
              table in the Bugzilla database.
 Parameters:  $table - the table name
 Returns:     array of column names

=cut

    my($self, $table) = @_;
    my @ddl = ();

    my $thash = $self->{schema}{$table};
    ThrowCodeError("Table $table does not exist in the database schema.")
      unless (ref($thash));

    my @columns = ();
    my @fields = @{ $thash->{FIELDS} };
    while (@fields) {
        push(@columns, shift(@fields));
        shift(@fields);
    }

    return @columns;

} #eosub--get_table_columns
#--------------------------------------------------------------------------
sub get_table_ddl {

=item C<get_table_ddl>

 Description: Public method to generate the SQL statements needed to create
              the a given table and its indexes in the Bugzilla database.
              Subclasses may override or extend this method, if needed, but
              subclasses probably should override C<_get_create_table_ddl>
              or C<_get_create_index_ddl> instead.
 Parameters:  $table - the table name
 Returns:     an array of strings containing SQL statements

=cut

    my($self, $table) = @_;
    my @ddl = ();

    ThrowCodeError("Table $table does not exist in the database schema.")
      unless (ref($self->{schema}{$table}));

    my $create_table = $self->_get_create_table_ddl($table);
    push(@ddl, $create_table) if $create_table;

    my @indexes = @{ $self->{schema}{$table}{INDEXES} || [] };
    while (@indexes) {
        my $index_name = shift(@indexes);
        my $index_info = shift(@indexes);
        my($index_fields,$index_type);
        if (ref($index_info) eq 'HASH') {
            $index_fields = $index_info->{FIELDS};
            $index_type = $index_info->{TYPE};
        } else {
            $index_fields = $index_info;
            $index_type = '';
        }
        my $index_sql = $self->_get_create_index_ddl($table,
                                                     $index_name,
                                                     $index_fields,
                                                     $index_type);
        push(@ddl, $index_sql) if $index_sql;
    }

    push(@ddl, @{ $self->{schema}{$table}{DB_EXTRAS} })
      if (ref($self->{schema}{$table}{DB_EXTRAS}));

    return @ddl;

} #eosub--get_table_ddl
#--------------------------------------------------------------------------
sub _get_create_table_ddl {

=item C<_get_create_table_ddl>

 Description: Protected method to generate the "create table" SQL statement
              for a given table.
 Parameters:  $table - the table name
 Returns:     a string containing the DDL statement for the specified table

=cut

    my($self, $table) = @_;

    my $thash = $self->{schema}{$table};
    ThrowCodeError("Table $table does not exist in the database schema.")
      unless (ref($thash));

    my $create_table = "CREATE TABLE $table \(\n";

    my @fields = @{ $thash->{FIELDS} };
    while (@fields) {
        my $field = shift(@fields);
        my $finfo = shift(@fields);
        $create_table .= "\t$field\t" . $self->get_type_ddl($finfo);
        $create_table .= "," if (@fields);
        $create_table .= "\n";
    }

    $create_table .= "\)";

    return($create_table)

} #eosub--_get_create_table_ddl
#--------------------------------------------------------------------------
sub _get_create_index_ddl {

=item C<_get_create_index_ddl>

 Description: Protected method to generate a "create index" SQL statement
              for a given table and index.
 Parameters:  $table_name - the name of the table
              $index_name - the name of the index
              $index_fields - a reference to an array of field names
              $index_type (optional) - specify type of index (e.g., UNIQUE)
 Returns:     a string containing the DDL statement

=cut

    my($self, $table_name, $index_name, $index_fields, $index_type) = @_;

    my $sql = "CREATE ";
    $sql .= "$index_type " if ($index_type eq 'UNIQUE');
    $sql .= "INDEX $index_name ON $table_name \(" .
      join(", ", @$index_fields) . "\)";

    return($sql);

} #eosub--_get_create_index_ddl
#--------------------------------------------------------------------------
1;
__END__

=back

=head1 ABSTRACT DATA TYPES

The following abstract data types are used:

=over 4

=item C<BOOLEAN>

=item C<INT1>

=item C<INT2>

=item C<INT3>

=item C<INT4>

=item C<SMALLSERIAL>

=item C<MEDIUMSERIAL>

=item C<INTSERIAL>

=item C<TINYTEXT>

=item C<MEDIUMTEXT>

=item C<TEXT>

=item C<LONGBLOB>

=item C<DATETIME>

=back

Database-specific subclasses should define the implementation for these data
types as a hash reference stored internally in the schema object as
C<db_specific>. This is typically done in overriden L<_initialize> method.

The following abstract boolean values should also be defined on a
database-specific basis:

=over 4

=item C<TRUE>

=item C<FALSE>

=back

=head1 SEE ALSO

L<Bugzilla::DB>

=cut
