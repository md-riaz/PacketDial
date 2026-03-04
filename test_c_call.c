#include <pjlib.h>
#include <pjlib-util.h>
#include <pjnath.h>
#include <pjsip.h>
#include <pjsip_ua.h>
#include <pjsua-lib/pjsua.h>
#include <stdio.h>

static void on_reg_state(pjsua_acc_id acc_id) {
    pjsua_acc_info info;
    pjsua_acc_get_info(acc_id, &info);
    printf("Registration state: %d\n", info.status);
}

int main() {
    pj_status_t status = pjsua_create();
    if (status != PJ_SUCCESS) return 1;

    pjsua_config cfg;
    pjsua_config_default(&cfg);
    cfg.cb.on_reg_state = &on_reg_state;

    pjsua_logging_config log_cfg;
    pjsua_logging_config_default(&log_cfg);
    log_cfg.level = 4;
    log_cfg.console_level = 4;

    status = pjsua_init(&cfg, &log_cfg, NULL);
    if (status != PJ_SUCCESS) return 1;

    pjsua_transport_config tp_cfg;
    pjsua_transport_config_default(&tp_cfg);
    pjsua_transport_id tp_id;
    pjsua_transport_create(PJSIP_TRANSPORT_UDP, &tp_cfg, &tp_id);

    pjsua_start();

    pjsua_acc_config acc_cfg;
    pjsua_acc_config_default(&acc_cfg);
    acc_cfg.id = pj_str("sip:127@cpx.alphapbx.net");
    acc_cfg.reg_uri = pj_str("sip:cpx.alphapbx.net");
    acc_cfg.cred_count = 1;
    acc_cfg.cred_info[0].realm = pj_str("*");
    acc_cfg.cred_info[0].scheme = pj_str("digest");
    acc_cfg.cred_info[0].username = pj_str("127");
    acc_cfg.cred_info[0].data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
    acc_cfg.cred_info[0].data = pj_str("Pkggq3Rq7");

    pjsua_acc_id acc_id;
    status = pjsua_acc_add(&acc_cfg, PJ_TRUE, &acc_id);
    
    pj_thread_sleep(2000);

    pj_str_t dst_uri = pj_str("sip:127@cpx.alphapbx.net:8090");
    pjsua_call_id call_id;
    status = pjsua_call_make_call(acc_id, &dst_uri, NULL, NULL, NULL, &call_id);
    if (status != PJ_SUCCESS) {
        char err_msg[256];
        pj_strerror(status, err_msg, sizeof(err_msg));
        printf("CALL FAILED: %d - %s\n", status, err_msg);
    } else {
        printf("CALL SUCCESS\n");
    }

    pj_thread_sleep(2000);
    pjsua_destroy();
    return 0;
}
