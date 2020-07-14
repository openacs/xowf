ad_include_contract {
    Embed proctoring support in a page.

    This template creates and empty page embedding specified URL in an
    iframe surrounded by proctoring support.

    This kind of proctoring will take snapshots from camera and
    desktop at random intervals and upload them to specified URL.

    @param exam_id Id of the exam. This can be e.g. the item_id of the
           exam object.
    @param exam_url URL of the actual exam, which will be included in
           an iframe.
    @param min_ms_interval miniumum time to the next snapshot in
           missliseconds
    @param max_ms_interval maximum time to the next snapshot in
           milliseconds.
    @param audio_p decides if we record audio. Every time some input
           longer than min_audio_duration is detected from the
           microphone, a recording will be started and terminated at
           the next silence, or once it reaches max_audio_duration
    @param min_audio_duration minimum audio duration to start
           recording in seconds
    @param max_audio_duration max audio duration in seconds. Once
           reached, recording will stop and resume at the next
           detected audio segment.
    @param preview_p if specified, a preview of recorded inputs will
                     be displayed to users during proctored session
    @param proctoring_p Do the actual proctoring. Can be disabled to
                        display just the exmaination statement
    @param examination_statement_p Display the examination statement
    @param examination_statement_url URL we are calling in order to
           store acceptance of the examination statement. It will
           receive 'object_id' as query parameter.
    @param upload_url URL for the backend receiving and storing the
           collected snapshots. It will receive 'name' (device name,
           either camera or desktop), item_id (exam_id), and the
           file. Current default URL is real and will store the
           pictures in the /proctoring folder under acs_root_dir.

    @author Antonio Pisano (antonio@elettrotecnica.it)
    @author Gustaf Neumann
} {
    object_url:localurl
    object_id:naturalnum,notnull
    {min_ms_interval:naturalnum  1000}
    {max_ms_interval:naturalnum 60000}
    {audio_p:boolean true}
    {min_audio_duration:naturalnum 2}
    {max_audio_duration:naturalnum 60}
    {preview_p:boolean true}
    {proctoring_p:boolean true}
    {examination_statement_p:boolean true}
    {examination_statement_url:localurl "/examination-statement-accept"}
    {upload_url:localurl "/proctoring-upload"}
}

if {0} {
    #
    # Add the following two files to the www (or subsite/www)
    # directory of your site. This should be handled more elegantly,
    # probably via registering the handline directly by naviserver
    # during package init.
    #
    #### www/proctoring-upload.adp
    <include src="/packages/xowf/lib/proctoring-upload"
     &="file"
     &="file.tmpfile"
     &="name"
     &="type"
     &="object_id"
    >
    ### www/proctoring-upload.tcl
    ad_page_contract {
    } {
       name:oneof(camera|desktop),notnull
       type:oneof(image|audio),notnull
       object_id:naturalnum,notnull
       file
       file.tmpfile
   }  
}

if {[apm_package_installed_p tlf-lrn-core]} {
    set msg(missing_stream)    [_ tlf-lrn-core.proctoring_missing_stream_message]
    set msg(proctoring_accept) [_ tlf-lrn-core.proctoring_accept_message]
    set msg(exam_mode)         [_ tlf-lrn-core.Exam_mode_message]
    set msg(proctoring_banner) [_ tlf-lrn-core.proctoring_banner_message]
    set msg(accept)            [_ tlf-lrn-core.Accept]
} else {
    set msg(missing_stream)    "missing stream"   
    set msg(proctoring_accept)  {
	An automated exam-supervision is activated to detect any
        fraudulent examination performance. You and your screen will
        be recorded. Your data will only be used for the stated
        purpose, will be stored securely and will not be passed on to
        third parties.
    }
    set msg(proctoring_banner) "This browser window is running in exam mode. Close this browser window after the exam."
    set msg(accept)            "Accept"
    set msg(exam_mode)         {
	<h4>Examination Statement</h4>
	<h5>1.) Participation</h5>
    <p> Only students who are officially registered for the course and/or the examination may take the exam.</p>
    <p>The exam is only graded if all 3 of the following conditions have been fulfilled:</p>
    <ul>
    <li><p>You have uploaded a photo that fulfills the necessary criteria to confirm your identity</p>
    <li><p>You have consented to automated online supervision, if previously announced for this examination</p>
    <li><p>You have confirmed that you have read and understood this examination statement</p>
    </ul>
    
    <p>If you have received the examination but not fulfilled the
    identity requirement and/or confirmed your consent to online
    supervision, the examination will be declared VOID and will count
    as an examination attempt. If you have not confirmed that you have
    read and understood this examination statement, your examination
    will not be graded and the attempt will not be counted.</p>
    
    <h5>2.) Technical requirements</h5>

    <p>It is your responsibility to ensure that you will not be
    disturbed during the examination and that all technical
    requirements (as previously announced) are fulfilled (see
    "Information on this examination environment" and/or "Confirmation
    of access to examination" in your online exam environment).<br/>
    &nbsp;</p>

    <h5>3.) Starting and terminating/interrupting the examination</h5>

    <p>By confirming that you have read and understood this
    examination statement, you also confirm receipt of the
    examination, and the attempt will be counted. The exam will be
    graded and counted towards your total number of permissible
    examination attempts. This applies even if you terminate the exam
    prematurely or do not submit your completed exam.</p>

    <p>If you are forced to terminate the exam prematurely or
    interrupt the exam due to technical difficulties (e.g. loss of
    your internet connection), please contact the person responsible
    for the examination without delay. To do so, please use the team
    set up in Microsoft Teams specifically for the exam in
    question. Report the termination/interruption of your exam in the
    channel "Reporting technical difficulties" and be sure to include
    the following information:</p>

    <ul>
    <li><p>Your student ID number</p>
    <li><p>Exact time of termination/interruption</p>
    <li><p>Screenshot of the error message, if applicable</p>
    </ul>

    <p>If you are able to solve the problem and continue with the
    exam, please report this on the same Microsoft Teams channel with
    the message "Examination resumed." You will find the direct link
    to Teams in the portlet "Information on this examination
    environment" on the starting page of the examination
    environment. We recommend downloading and installing the Microsoft
    Teams desktop app both on your computer and on your mobile
    device.</p>

    <p>All instances of termination/interruption reported
    through this channel will be reviewed individually to decide if
    the examination will be graded and the attempt counted towards the
    student's total number of permissible attempts.<br/> &nbsp;</p>

    <h5>4.) Cheating and identity confirmation</h5>

    <p>Any attempt to cheat on the exam (e.g. cell phone, consulting
    forbidden materials, consulting other people) will result in the
    exam being declared VOID and the examination attempt counted. You
    will also be blocked from re-registering to repeat the examination
    for a period of 4 months starting from the examination date.</p>

    <p>To confirm your identity, you will be required to upload a
    photo of your face and the student ID or other official photo ID
    to the online examination environment. If anyone attempts to take
    an exam on behalf of another person, he or she will
    <strong>without exception</strong> be reported to the public
    prosecutor's office for charges of forgery, which may result in a
    criminal record.</p> <p>If announced in advance by the person
    responsible for the exam, automated online examination supervision
    will be conducted for the duration of the exam. This means that
    you and your screen will be monitored by camera and microphone
    throughout the exam, and the examiner will be able to see and hear
    the recording. You need to consent to this supervision in advance
    in the online examination environment under "Consent to automated
    online supervision." As soon as you start the exam, you will need
    to give your browser permission to access your screen, webcam, and
    microphone.<br/> &nbsp;</p>

    <h5>5.) Permissible aids</h5>

    <p>When taking this examination, you may use only the aids
    explicitly listed by the person responsible for the examination
    under "Information on this online examination environment."</p>
    }
}

set mobile_p [ad_conn mobile_p]
set preview_p [expr {$preview_p ? true : false}]
set proctoring_p [expr {$proctoring_p ? true : false}]

