import SwiftUI

/// Compile-time string table so LocalizedStringKey lookups never silently miss.
/// Values live in Localizable.strings; this enum documents the keys in one place.
enum L10n {
    static let tabs = [
        "tab.schedule",
        "tab.settings",
    ]

    static let schedule = [
        "schedule.title",
        "schedule.addCourse",
        "schedule.showDay",
        "schedule.showWeek",
        "schedule.previousWeek",
        "schedule.nextWeek",
        "schedule.noTerm.title",
        "schedule.noTerm.message",
    ]

    static let week = [
        "week.number",
        "week.notStarted",
        "week.termStartMissing",
    ]

    static let weekdays = [
        "weekday.monday", "weekday.tuesday", "weekday.wednesday",
        "weekday.thursday", "weekday.friday", "weekday.saturday", "weekday.sunday",
        "weekday.narrow.monday", "weekday.narrow.tuesday", "weekday.narrow.wednesday",
        "weekday.narrow.thursday", "weekday.narrow.friday", "weekday.narrow.saturday",
        "weekday.narrow.sunday",
        "common.unknown",
    ]

    static let course = [
        "course.new",
        "course.edit",
        "course.quickAdd",
        "course.detail",
        "course.delete",
        "course.delete.confirm",
        "course.delete.message",
        "course.hide",
        "course.hide.footer",
        "course.field.title",
        "course.field.teacher",
        "course.field.location",
        "course.field.category",
        "course.field.day",
        "course.field.periods",
        "course.field.startTime",
        "course.field.endTime",
        "course.field.customClock",
        "course.field.weeks",
        "course.category.course",
        "course.category.exam",
        "course.examTag",
        "course.section.basic",
        "course.section.time",
        "course.section.weeks",
        "course.section.color",
        "course.weeks.all",
        "course.weeks.odd",
        "course.weeks.even",
        "course.weeks.clear",
        "course.weeks.emptyHint",
        "course.weekSummary",
        "course.weekSummary.all",
        "course.weekRange",
        "course.color.auto",
        "course.color.pick",
        "course.conflict.title",
        "course.conflict.hint",
        "course.activeThisWeek",
        "course.inactiveThisWeek",
        "course.color.conflictTitle",
    ]

    static let today = [
        "today.title",
        "today.completed",
        "today.endsIn",
        "today.next",
        "today.freeNow",
        "today.nextStartsIn",
        "today.allClear",
        "today.doneForToday",
        "day.empty.title",
        "day.empty.message",
    ]

    static let settings = [
        "settings.term",
        "settings.timing",
        "settings.appearance",
        "settings.section.schedule",
        "settings.about",
        "settings.about.footer",
        "app.version",
        "term.picker",
        "term.create",
        "term.newName",
        "term.name",
        "term.startDate",
        "term.weekCountLabel",
        "term.weekCount",
        "term.courseCount",
        "term.footer",
        "timing.slots.header",
        "timing.slots.footer",
        "timing.reset",
        "appearance.accent",
        "appearance.palette",
        "appearance.palette.header",
        "appearance.palette.footer",
        "appearance.weekStart",
        "appearance.weekStart.monday",
        "appearance.weekStart.sunday",
        "appearance.showWeekend",
        "appearance.grid.header",
        "accent.teal",
        "accent.green",
        "accent.blue",
        "accent.purple",
        "accent.orange",
        "accent.pink",
        "palette.default",
        "palette.morandi",
        "palette.macaron",
        "palette.vibrant",
        "palette.vintage",
    ]

    static let misc = [
        "common.cancel",
        "common.save",
        "common.add",
        "common.done",
        "common.unknown",
        "list.separator",
        "schedule.period",
        "schedule.periodRange",
        "schedule.periodSlots",
        "duration.lessThanMinute",
        "duration.minutes",
        "duration.hours",
        "duration.hoursMinutes",
        "term.season.spring",
        "term.season.autumn",
    ]

    static let all: [String] = tabs + schedule + week + weekdays + course + today + settings + misc
}
