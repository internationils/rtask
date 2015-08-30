//
// Welcome to rtask - a simple text-based task and todo manager
// 
// WORK IN PROGRESS - this is early Alpha quality!
//

//
// ITEM STRUCTURE
//
// each line is a task or a piece of information.
// items can be continued on subsequent lines via '\'
// blank lines are ignored
// multiple spaces  are   treated    as    one      space       ...
This is a plain simple todo item
Each line is a task or a piece of information
This task has a very long description that requires \
        a second line to completely describe it

//
// COMMENTS
//
// comments are started by a '//'
// they can start at the beginning or in the middle of a line
// if started in the middle of a line, continue to the end of the line
// comments cannot be continued across multiple lines via '\'
// comments that are part of items are preserved when processing, whole-line comments are ignored / dopped
Take out the trash // comments can be at the end of a task as well

//
// META-INFORMATION
//
// items can contain meta-information
// this is indicated be prefacing it with one of +@&#! (prefix)
// they _must_ be preceded by a space, and the meta-information is terminated by a space
// these prefixes indicate +projects @locations &types #tags !priority
// this is not meta-information: doodle@email.com since there is no space before the '@'
// this is: @work ...due to the space before the '@'
// meta-information can be extended as in @car.volvo or +project.subproject.topic
// blank meta information is ignored, as in + ! & # @
// meta-information can not contain spaces
// meta-information can be hierarchical via the '.' concatenator (eg. #task.subtask.subsubtask)
// meta-information are case insensitive (#d is equivalent to #D, for example)
// priorities can only be set once per item, other meta-information can have multiple assignments

//
// PROJECTS / GROUPS: '+' prefix
// use this to assign items to projects or groups
//
This is part of the project / group work +work
This item is a topic in a subproject in a project +project.subproject.topic
This is a phone call to make +call

//
// LOCATION / SCOPE: '@' prefix
// use this to specify where an action can take place
//
This task is doable at home @home // @<somewhere> indicates a location where the task can be done
This phone call can be made at home, work, or in the car +call @home @work @car // can't do this on a @plane...

//
// TYPE: '&' prefix
// use this to define what type of item this is
//
This task is type todo &todo // types are helpful to figure out what to do with an item
There are other task types &info // other standard GTD types are wait, later, info etc. but you can use anything you wish here (reminder, scratchpad, whatever...)
"There are special characters which have a significance when processing the todo file. +@&# should not be used in a task name, else the task must be quoted" &info

//
// PRIORITY: '!' prefix
// use this to set priorities
//
// priorities are sorted alphabetically giving complete freedom to define a priority convention
// a task can (currently?) not contain more than one priority
// Example: !1, !2, !3, ...
// Example: !p1, !p2, !p3, ... !pz
// Example: !alpha, !beta, !gamma, !delta, ...
This task is important !p1
This task is also important !pa
This one is unimportant !pz
This one is also unimportant !p999

//
// TAGS: '#' prefix
// use this to add any other information to the item
//
// tags can be used to add any meta-information to a tag that you want.
// tags are can be either a simple tag, or a key:value pair
// keys must start with a letter, values can start with a number. Both cannot contain spaces.
// values for tags are CaSe SeNsItIvE (as opposed to the key-part and the other meta-information)
This task has a simple tag #informative
This task has a key / value pair tag #infotype:vital
This task is expensive #cost:2000
This task has sub- and sub-sub-levels #task.subtask.subsubtask)


//
// SPECIAL TAG: DATES
//
// dates can be formatted in two ways: yyyy-mm-dd or yyyymmdd (further date formats may be added later)
// todo: add a #opt:dateformat <locale> configure option
// there are several date tags that you can use
// #d<date> due date for a task. 
// #d If no due date is set, today is assumed as the due date when the file is saved.
// #d+<days> set the due date X days from the day of the saving of the file.
// #n<date> new date. #n without a date will cause the current date to be written when the file is saved.
// #n-<days> will set a new date X days ago
// #z<date> completion date. +/-/blank can be used here as well
#d2014-08-30 This task is due at the end of August
#d2014-08-30 This task is due at the end of August, created at the beginning of August, and completed middle of September #n2014-0801 #z2014-09-15 // dates can be at the beginning or end of a task

//
// OUTPUT
//
// the command line tool can be used to manipulate and output the task file
// the output can be formated
// both the tasks (each line) and the structure of the file can be defined

// there are several basic options
#opt:writedatesep:true // write the locale-appropriate date separators (usually dashes or dots)
#opt:sortonwrite:false // to protect the structure of a file (like this one), disable sorting. This overrides the file structure option. New tasks are written where they were, or, if added with the CLI, where they are placed in the file.

// the line is composed of any of the following in an arbitrary order
#opt:lineformat due prio task group location type tags new complete

// the file can be structured in form
open tasks by date
anything that has a duedate
#opt:hasduedate:true
