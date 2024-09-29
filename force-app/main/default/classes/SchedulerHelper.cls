public class SchedulerHelper {
    public static void scheduleSessionResetJobs() {
        String jobNamePrefix = 'ResetCustomerSessionsJob_';
        // Cron expression template: Seconds Minutes Hours DayOfMonth Month DayOfWeek OptionalYear
        String cronExpressionTemplate = '0 {0} * * * ?';

        // Unschedule any existing jobs with the same name prefix
        String jobNamePattern = jobNamePrefix + '%';
        for (CronTrigger ct : [SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name LIKE :jobNamePattern]) {
            System.abortJob(ct.Id);
        }

        // Schedule jobs at every 10-minute interval (0, 10, 20, 30, 40, 50)
        Integer[] minuteIntervals = new Integer[] {0, 10, 20, 30, 40, 50};
        for (Integer minute : minuteIntervals) {
            String jobName = jobNamePrefix + minute;
            String cronExpression = cronExpressionTemplate.replace('{0}', String.valueOf(minute));
            System.schedule(jobName, cronExpression, new ResetCustomerSessions());
        }

        // Schedule an immediate job to run now or at the next minute
        String immediateJobName = jobNamePrefix + 'Immediate';
        String immediateCronExpression = getImmediateCronExpression();
        System.schedule(immediateJobName, immediateCronExpression, new ResetCustomerSessions());
    }

    private static String getImmediateCronExpression() {
        Datetime now = System.now();
        Integer nextMinute = Math.mod(now.minute() + 1, 60);
        Integer hour;

        if (nextMinute == 0) {
            hour = Math.mod(now.hour() + 1, 24);
        } else {
            hour = now.hour();
        }

        String cronExpression = '0 ' + String.valueOf(nextMinute) + ' ' + String.valueOf(hour) + ' * * ?';
        return cronExpression;
    }
}
