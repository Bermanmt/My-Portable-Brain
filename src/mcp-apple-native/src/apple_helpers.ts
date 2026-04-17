export async function runJXA(script: string): Promise<any> {
  const proc = Bun.spawn(["osascript", "-l", "JavaScript", "-e", script], {
    stdout: "pipe",
    stderr: "pipe",
  });

  const output = await new Response(proc.stdout).text();
  await proc.exited;

  if (!output.trim()) return [];
  return JSON.parse(output.trim());
}

// NOTE: .where() with date ranges is unreliable in JXA / Apple Calendar.
// We fetch all events from each calendar and filter in JS instead.
export const getCalendarEventsScript = (days: number) => `
function run() {
  const Calendar = Application("Calendar");
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const end = new Date(today);
  end.setDate(end.getDate() + ${days});

  const calendars = Calendar.calendars();
  let results = [];

  calendars.forEach(function(cal) {
    try {
      const allEvents = cal.events();
      allEvents.forEach(function(e) {
        try {
          const start = e.startDate();
          if (start >= today && start < end) {
            results.push({
              calendar: cal.name(),
              title: e.summary() || "",
              start: start.toISOString(),
              end: e.endDate().toISOString(),
              location: e.location() || "",
              url: e.url() || ""
            });
          }
        } catch(err) {}
      });
    } catch(err) {}
  });

  results.sort(function(a, b) { return new Date(a.start) - new Date(b.start); });
  return JSON.stringify(results);
}
`;

export const getRecentEmailsScript = (limit: number) => `
function run() {
  const Mail = Application("Mail");
  let results = [];
  try {
    const allAccounts = Mail.accounts();
    allAccounts.forEach(function(account) {
      try {
        const mailboxes = account.mailboxes();
        mailboxes.forEach(function(mb) {
          try {
            const name = mb.name().toLowerCase();
            if (name === "inbox" || name === "bandeja de entrada") {
              const messages = mb.messages();
              messages.slice(0, ${limit}).forEach(function(m) {
                try {
                  results.push({
                    subject: m.subject() || "",
                    sender: m.sender() || "",
                    date: m.dateSent().toISOString(),
                    isRead: m.readStatus()
                  });
                } catch(err) {}
              });
            }
          } catch(err) {}
        });
      } catch(err) {}
    });
  } catch(e) {}
  results.sort(function(a,b) { return new Date(b.date) - new Date(a.date); });
  return JSON.stringify(results.slice(0, ${limit}));
}
`;

