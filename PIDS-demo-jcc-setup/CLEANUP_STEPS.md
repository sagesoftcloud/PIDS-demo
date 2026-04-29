# Cleanup Steps - PIDS-demo-jcc

**⚠️ IMPORTANT:** Follow these steps IN ORDER to properly delete all resources and avoid charges.

---

## Step 1: Delete Auto Scaling Group (FIRST)

**Why first?** The ASG controls the instances. Delete it first to stop creating new ones.

1. Go to **EC2** → **Auto Scaling Groups**
2. Select `PIDS-demo-jcc-asg` (check the box)
3. Click **Actions** → **Delete**
4. Type `delete` in the confirmation box
5. Click **Delete**
6. **Wait 2-3 minutes** for all instances to terminate

**Verify:** Go to EC2 → Instances, confirm no instances with tag "PIDS-demo-jcc" are running

---

## Step 2: Delete Load Balancer (SECOND)

1. Go to **EC2** → **Load Balancers**
2. Select `PIDS-demo-jcc-alb` (check the box)
3. Click **Actions** → **Delete load balancer**
4. Type `confirm` in the box
5. Click **Delete**

**Wait 1-2 minutes** for deletion to complete

---

## Step 3: Delete Target Group (THIRD)

1. Go to **EC2** → **Target Groups**
2. Select `PIDS-demo-jcc-tg` (check the box)
3. Click **Actions** → **Delete**
4. Click **Yes, delete**

---

## Step 4: Delete Launch Template

1. Go to **EC2** → **Launch Templates**
2. Select `PIDS-demo-jcc-template` (check the box)
3. Click **Actions** → **Delete template**
4. Type `Delete` in the box
5. Click **Delete**

---

## Step 5: Delete Security Groups

**Note:** If you get an error, wait 2-3 minutes and try again. AWS needs time to remove dependencies.

### 5.1 Delete Instance Security Group

1. Go to **EC2** → **Security Groups**
2. Select `PIDS-demo-jcc-instance-sg` (check the box)
3. Click **Actions** → **Delete security groups**
4. Click **Delete**

### 5.2 Delete ALB Security Group

1. Select `PIDS-demo-jcc-alb-sg` (check the box)
2. Click **Actions** → **Delete security groups**
3. Click **Delete**

**If deletion fails:** Wait 5 minutes and try again. Network interfaces may still be attached.

---

## Step 6: Delete Key Pair

1. Go to **EC2** → **Key Pairs**
2. Select `PIDS-demo-jcc-key` (check the box)
3. Click **Actions** → **Delete**
4. Type `Delete` in the box
5. Click **Delete**
6. **Also delete the .pem file from your computer**

---

## Verification Checklist

After cleanup, verify all resources are deleted:

- [ ] Auto Scaling Group deleted
- [ ] No instances with tag "PIDS-demo-jcc" running
- [ ] Load Balancer deleted
- [ ] Target Group deleted
- [ ] Launch Template deleted
- [ ] Both Security Groups deleted
- [ ] Key Pair deleted
- [ ] .pem file deleted from computer

---

## Final Verification

### Check EC2 Dashboard

1. Go to **EC2 Dashboard**
2. Verify:
   - **Instances:** 0 running with "PIDS-demo-jcc" tag
   - **Load Balancers:** 0 with "PIDS-demo-jcc" name
   - **Target Groups:** 0 with "PIDS-demo-jcc" name
   - **Launch Templates:** 0 with "PIDS-demo-jcc" name
   - **Security Groups:** 0 with "PIDS-demo-jcc" name
   - **Key Pairs:** 0 with "PIDS-demo-jcc" name

### Check Billing

1. Go to **Billing Dashboard**
2. Check **Cost Explorer** (may take 24 hours to update)
3. Verify no ongoing charges for:
   - EC2 instances
   - Load Balancers
   - Data transfer

---

## Troubleshooting Cleanup Issues

### Security Group Won't Delete

**Error:** "has a dependent object"

**Solution:**
1. Wait 5 minutes
2. Check if any network interfaces are still attached
3. Go to **EC2** → **Network Interfaces**
4. Delete any interfaces associated with the security group
5. Try deleting security group again

### Load Balancer Taking Long to Delete

**Normal:** Load balancers can take 2-5 minutes to delete

**If stuck:**
1. Refresh the page
2. Check if it's in "deleting" state
3. Wait up to 10 minutes
4. If still stuck, contact AWS support

### Instances Still Running

**Check:**
1. Go to **Auto Scaling Groups**
2. Verify ASG is deleted
3. Go to **EC2** → **Instances**
4. Manually terminate any remaining instances with "PIDS-demo-jcc" tag

---

## Cost After Cleanup

After successful cleanup:
- **Hourly cost:** $0.00
- **Daily cost:** $0.00
- **Monthly cost:** $0.00

**Note:** You may see small charges for the time resources were running. This is normal.

---

## Cleanup Completion Time

**Total time:** 10-15 minutes
- ASG deletion: 2-3 minutes
- ALB deletion: 2-3 minutes
- Other resources: 5 minutes
- Verification: 2 minutes

---

## Summary

**Resources Deleted:**
1. ✅ Auto Scaling Group (PIDS-demo-jcc-asg)
2. ✅ 2 EC2 Instances (auto-terminated)
3. ✅ Application Load Balancer (PIDS-demo-jcc-alb)
4. ✅ Target Group (PIDS-demo-jcc-tg)
5. ✅ Launch Template (PIDS-demo-jcc-template)
6. ✅ Instance Security Group (PIDS-demo-jcc-instance-sg)
7. ✅ ALB Security Group (PIDS-demo-jcc-alb-sg)
8. ✅ Key Pair (PIDS-demo-jcc-key)

**VPC:** vpc-049501e2e003cb81b (NOT deleted - it's shared)

---

## Important Notes

⚠️ **Do NOT delete the VPC** - It's shared and may be used by other resources

⚠️ **Always verify cleanup** - Check the EC2 Dashboard to ensure all resources are gone

⚠️ **Monitor billing** - Check your AWS bill in 24 hours to confirm no ongoing charges

---

**Cleanup completed on:** _______________

**Verified by:** _______________
