//////////////////////////////////////////////////////////////////////////////////////
//
// (C) Daniel Strano and the Qimcifa contributors, 2022, 2023. All rights reserved.
//
// This header has been adapted for OpenCL and C, from big_integer.c by Andre Azevedo.
//
// Original file:
//
// big_integer.c
//     Description: "Arbitrary"-precision integer
//     Author: Andre Azevedo <http://github.com/andreazevedo>
//
// The MIT License (MIT)
//
// Copyright (c) 2014 Andre Azevedo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#if 0
// For JIT OpenCL compilation, you can specify and modify these in the host code
// to load the OpenCL program.
#define BIG_INTEGER_WORD_SIZE 2
#define BIG_INTEGER_HALF_WORD_SIZE 4
#define BIG_INTEGER_MAX_WORD_INDEX 1
#define BIG_INTEGER_BITS 128
#define BIG_INTEGER_WORD_BITS 64
#define BIG_INTEGER_WORD_POWER 6
#define BIG_INTEGER_WORD unsigned long
#define BIG_INTEGER_HALF_WORD unsigned
#define BIG_INTEGER_HALF_WORD_BITS 32
#define BIG_INTEGER_HALF_WORD_POW 0x100000000UL
#define BIG_INTEGER_HALF_WORD_MASK 0xFFFFFFFFUL
#define BIG_INTEGER_HALF_WORD_MASK_NOT 0xFFFFFFFF00000000UL
#endif

typedef struct BigInteger {
    BIG_INTEGER_WORD bits[BIG_INTEGER_WORD_SIZE];
} BigInteger;

inline void bi_set_0(BigInteger* p)
{
    for (int i = 0; i < BIG_INTEGER_WORD_SIZE; ++i) {
        p->bits[i] = 0;
    }
}

inline BigInteger bi_copy(const BigInteger* in)
{
    BigInteger result;
    for (int i = 0; i < BIG_INTEGER_WORD_SIZE; ++i) {
        result.bits[i] = in->bits[i];
    }
    return result;
}

inline void bi_copy_ip(const BigInteger* in, BigInteger* out)
{
    for (int i = 0; i < BIG_INTEGER_WORD_SIZE; ++i) {
        out->bits[i] = in->bits[i];
    }
}

inline int bi_compare(const BigInteger* left, const BigInteger* right)
{
    for (int i = BIG_INTEGER_MAX_WORD_INDEX; i >= 0; --i) {
        if (left->bits[i] > right->bits[i]) {
            return 1;
        }
        if (left->bits[i] < right->bits[i]) {
            return -1;
        }
    }

    return 0;
}

inline int bi_compare_0(const BigInteger* left)
{
    for (int i = 0; i < BIG_INTEGER_WORD_SIZE; ++i) {
        if (left->bits[i]) {
            return 1;
        }
    }

    return 0;
}

inline int bi_compare_1(const BigInteger* left)
{
    for (int i = BIG_INTEGER_MAX_WORD_INDEX; i > 0; --i) {
        if (left->bits[i]) {
            return 1;
        }
    }
    if (left->bits[0] > 1) {
        return 1;
    }
    if (left->bits[0] < 1) {
        return -1;
    }

    return 0;
}

inline BigInteger bi_add(const BigInteger* left, const BigInteger* right)
{
    BigInteger result;
    result.bits[0] = 0;
    for (int i = 0; i < BIG_INTEGER_MAX_WORD_INDEX; ++i) {
        result.bits[i] += left->bits[i] + right->bits[i];
        result.bits[i + 1] = (result.bits[i] < left->bits[i]) ? 1 : 0;
    }
    result.bits[BIG_INTEGER_MAX_WORD_INDEX] += right->bits[BIG_INTEGER_MAX_WORD_INDEX];

    return result;
}

inline void bi_add_ip(BigInteger* left, const BigInteger* right)
{
    for (int i = 0; i < BIG_INTEGER_MAX_WORD_INDEX; ++i) {
        BIG_INTEGER_WORD temp = left->bits[i];
        left->bits[i] += right->bits[i];
        int j = i;
        while ((j < BIG_INTEGER_MAX_WORD_INDEX) && (left->bits[j] < temp)) {
            temp = left->bits[++j]++;
        }
    }
    left->bits[BIG_INTEGER_MAX_WORD_INDEX] += right->bits[BIG_INTEGER_MAX_WORD_INDEX];
}

inline BigInteger bi_sub(const BigInteger* left, const BigInteger* right)
{
    BigInteger result;
    result.bits[0] = 0;
    for (int i = 0; i < BIG_INTEGER_MAX_WORD_INDEX; ++i) {
        result.bits[i] += left->bits[i] - right->bits[i];
        result.bits[i + 1] = (result.bits[i] > left->bits[i]) ? -1 : 0;
    }
    result.bits[BIG_INTEGER_MAX_WORD_INDEX] -= right->bits[BIG_INTEGER_MAX_WORD_INDEX];

    return result;
}

inline void bi_sub_ip(BigInteger* left, const BigInteger* right)
{
    for (int i = 0; i < BIG_INTEGER_MAX_WORD_INDEX; ++i) {
        BIG_INTEGER_WORD temp = left->bits[i];
        left->bits[i] -= right->bits[i];
        int j = i;
        while ((j < BIG_INTEGER_MAX_WORD_INDEX) && (left->bits[j] > temp)) {
            temp = left->bits[++j]--;
        }
    }
    left->bits[BIG_INTEGER_MAX_WORD_INDEX] -= right->bits[BIG_INTEGER_MAX_WORD_INDEX];
}

inline void bi_increment(BigInteger* pBigInt, BIG_INTEGER_WORD value)
{
    BIG_INTEGER_WORD temp = pBigInt->bits[0];
    pBigInt->bits[0] += value;
    if (temp <= pBigInt->bits[0]) {
        return;
    }
    for (int i = 1; i < BIG_INTEGER_WORD_SIZE; i++) {
        temp = pBigInt->bits[i]++;
        if (temp <= pBigInt->bits[i]) {
            break;
        }
    }
}

inline void bi_decrement(BigInteger* pBigInt, BIG_INTEGER_WORD value)
{
    BIG_INTEGER_WORD temp = pBigInt->bits[0];
    pBigInt->bits[0] -= value;
    if (temp >= pBigInt->bits[0]) {
        return;
    }
    for (int i = 0; i < BIG_INTEGER_WORD_SIZE; i++) {
        temp = pBigInt->bits[i]--;
        if (temp >= pBigInt->bits[i]) {
            break;
        }
    }
}

inline BigInteger bi_create(BIG_INTEGER_WORD val)
{
    BigInteger result;
    result.bits[0] = val;
    for (int i = 1; i < BIG_INTEGER_WORD_SIZE; ++i) {
        result.bits[i] = 0;
    }

    return result;
}

inline BigInteger bi_load(global BIG_INTEGER_WORD* a)
{
    BigInteger result;
    for (int i = 0; i < BIG_INTEGER_WORD_SIZE; ++i) {
        result.bits[i] = a[i];
    }

    return result;
}

inline BigInteger bi_lshift_word(const BigInteger* left, BIG_INTEGER_WORD rightMult)
{
    if (!rightMult) {
        return *left;
    }

    BigInteger result;
    for (int i = rightMult; i < BIG_INTEGER_WORD_SIZE; ++i) {
        result.bits[i] = left->bits[i - rightMult];
    }
    for (BIG_INTEGER_WORD i = 0; i < rightMult; ++i) {
        result.bits[i] = 0;
    }

    return result;
}

inline void bi_lshift_word_ip(BigInteger* left, BIG_INTEGER_WORD rightMult)
{
    if (!rightMult) {
        return;
    }
    for (int i = rightMult; i < BIG_INTEGER_WORD_SIZE; ++i) {
        left->bits[i] = left->bits[i - rightMult];
    }
    for (BIG_INTEGER_WORD i = 0; i < rightMult; ++i) {
        left->bits[i] = 0;
    }
}

inline BigInteger bi_rshift_word(const BigInteger* left, BIG_INTEGER_WORD rightMult)
{
    if (!rightMult) {
        return *left;
    }

    BigInteger result;
    for (int i = rightMult; i < BIG_INTEGER_WORD_SIZE; ++i) {
        result.bits[i - rightMult] = left->bits[i];
    }
    for (BIG_INTEGER_WORD i = 0; i < rightMult; ++i) {
        result.bits[BIG_INTEGER_MAX_WORD_INDEX - i] = 0;
    }

    return result;
}

inline void bi_rshift_word_ip(BigInteger* left, BIG_INTEGER_WORD rightMult)
{
    if (!rightMult) {
        return;
    }
    for (int i = rightMult; i < BIG_INTEGER_WORD_SIZE; ++i) {
        left->bits[i - rightMult] = left->bits[i];
    }
    for (BIG_INTEGER_WORD i = 0; i < rightMult; ++i) {
        left->bits[BIG_INTEGER_MAX_WORD_INDEX - i] = 0;
    }
}

inline BigInteger bi_lshift(const BigInteger* left, BIG_INTEGER_WORD right)
{
    const int rShift64 = right >> BIG_INTEGER_WORD_POWER;
    const int rMod = right - (rShift64 << BIG_INTEGER_WORD_POWER);

    BigInteger result = bi_lshift_word(left, rShift64);
    if (!rMod) {
        return result;
    }

    const int rModComp = BIG_INTEGER_WORD_BITS - rMod;
    BIG_INTEGER_WORD carry = 0;
    for (int i = 0; i < BIG_INTEGER_WORD_SIZE; ++i) {
        right = result.bits[i];
        result.bits[i] = carry | (right << rMod);
        carry = right >> rModComp;
    }

    return result;
}

inline void bi_lshift_ip(BigInteger* left, BIG_INTEGER_WORD right)
{
    const int rShift64 = right >> BIG_INTEGER_WORD_POWER;
    const int rMod = right - (rShift64 << BIG_INTEGER_WORD_POWER);

    bi_lshift_word_ip(left, rShift64);
    if (!rMod) {
        return;
    }

    const int rModComp = BIG_INTEGER_WORD_BITS - rMod;
    BIG_INTEGER_WORD carry = 0;
    for (int i = 0; i < BIG_INTEGER_WORD_SIZE; ++i) {
        right = left->bits[i];
        left->bits[i] = carry | (right << rMod);
        carry = right >> rModComp;
    }
}

inline BigInteger bi_rshift(const BigInteger* left, BIG_INTEGER_WORD right)
{
    const int rShift64 = right >> BIG_INTEGER_WORD_POWER;
    const int rMod = right - (rShift64 << BIG_INTEGER_WORD_POWER);

    BigInteger result = bi_rshift_word(left, rShift64);
    if (!rMod) {
        return result;
    }

    const int rModComp = BIG_INTEGER_WORD_BITS - rMod;
    BIG_INTEGER_WORD carry = 0;
    for (int i = BIG_INTEGER_MAX_WORD_INDEX; i >= 0; --i) {
        right = result.bits[i];
        result.bits[i] = carry | (right >> rMod);
        carry = right << rModComp;
    }

    return result;
}

inline void bi_rshift_ip(BigInteger* left, BIG_INTEGER_WORD right)
{
    const int rShift64 = right >> BIG_INTEGER_WORD_POWER;
    const int rMod = right - (rShift64 << BIG_INTEGER_WORD_POWER);

    bi_rshift_word_ip(left, rShift64);
    if (!rMod) {
        return;
    }

    const int rModComp = BIG_INTEGER_WORD_BITS - rMod;
    BIG_INTEGER_WORD carry = 0;
    for (int i = BIG_INTEGER_MAX_WORD_INDEX; i >= 0; --i) {
        right = left->bits[i];
        left->bits[i] = carry | (right >> rMod);
        carry = right << rModComp;
    }
}

inline int bi_log2(const BigInteger* n)
{
    int pw = 0;
    BigInteger p = bi_rshift(n, 1U);
    while (bi_compare_0(&p) != 0) {
        bi_rshift_ip(&p, 1U);
        ++pw;
    }
    return pw;
}

inline int bi_and_1(const BigInteger* left) { return left->bits[0] & 1; }

inline BigInteger bi_and(const BigInteger* left, const BigInteger* right)
{
    BigInteger result;
    for (int i = 0; i < BIG_INTEGER_WORD_SIZE; ++i) {
        result.bits[i] = left->bits[i] & right->bits[i];
    }

    return result;
}

inline void bi_and_ip(BigInteger* left, const BigInteger* right)
{
    for (int i = 0; i < BIG_INTEGER_WORD_SIZE; ++i) {
        left->bits[i] &= right->bits[i];
    }
}

inline BigInteger bi_or(const BigInteger* left, const BigInteger* right)
{
    BigInteger result;
    for (int i = 0; i < BIG_INTEGER_WORD_SIZE; ++i) {
        result.bits[i] = left->bits[i] | right->bits[i];
    }

    return result;
}

inline void bi_or_ip(BigInteger* left, const BigInteger* right)
{
    for (int i = 0; i < BIG_INTEGER_WORD_SIZE; ++i) {
        left->bits[i] |= right->bits[i];
    }
}

inline BigInteger bi_xor(const BigInteger* left, const BigInteger* right)
{
    BigInteger result;
    for (int i = 0; i < BIG_INTEGER_WORD_SIZE; ++i) {
        result.bits[i] = left->bits[i] ^ right->bits[i];
    }

    return result;
}

inline void bi_xor_ip(BigInteger* left, const BigInteger* right)
{
    for (int i = 0; i < BIG_INTEGER_WORD_SIZE; ++i) {
        left->bits[i] ^= right->bits[i];
    }
}

inline BigInteger bi_not(const BigInteger* left)
{
    BigInteger result;
    for (int i = 0; i < BIG_INTEGER_WORD_SIZE; ++i) {
        result.bits[i] = ~(left->bits[i]);
    }

    return result;
}

inline void bi_not_ip(BigInteger* left)
{
    for (int i = 0; i < BIG_INTEGER_WORD_SIZE; ++i) {
        left->bits[i] = ~(left->bits[i]);
    }
}

// "Schoolbook multiplication" (on half words)
// Complexity - O(x^2)
BigInteger bi_mul_small(const BigInteger* left, BIG_INTEGER_HALF_WORD right)
{
    BigInteger result = bi_create(0);
    BIG_INTEGER_WORD carry = 0;
    for (int i = 0; i < BIG_INTEGER_HALF_WORD_SIZE; ++i) {
        const int i2 = i >> 1;
        if (i & 1) {
            BIG_INTEGER_WORD temp = right * (left->bits[i2] >> BIG_INTEGER_HALF_WORD_BITS) + carry;
            carry = temp >> BIG_INTEGER_HALF_WORD_BITS;
            result.bits[i2] |= (temp & BIG_INTEGER_HALF_WORD_MASK) << BIG_INTEGER_HALF_WORD_BITS;
        } else {
            BIG_INTEGER_WORD temp = right * (left->bits[i2] & BIG_INTEGER_HALF_WORD_MASK) + carry;
            carry = temp >> BIG_INTEGER_HALF_WORD_BITS;
            result.bits[i2] |= temp & BIG_INTEGER_HALF_WORD_MASK;
        }
    }

    return result;
}

// "Schoolbook multiplication" (on half words)
// Complexity - O(x^2)
BigInteger bi_mul(const BigInteger* left, const BigInteger* right)
{
    if (right->bits[0] < BIG_INTEGER_HALF_WORD_POW) {
        int wordSize;
        for (wordSize = 1; wordSize < BIG_INTEGER_WORD_SIZE; ++wordSize) {
            if (right->bits[wordSize]) {
                break;
            }
        }
        if (wordSize == BIG_INTEGER_WORD_SIZE) {
            return bi_mul_small(left, (BIG_INTEGER_HALF_WORD)(right->bits[0]));
        }
    }

    if (left->bits[0] < BIG_INTEGER_HALF_WORD_POW) {
        int wordSize;
        for (wordSize = 1; wordSize < BIG_INTEGER_WORD_SIZE; ++wordSize) {
            if (left->bits[wordSize]) {
                break;
            }
        }
        if (wordSize == BIG_INTEGER_WORD_SIZE) {
            return bi_mul_small(right, (BIG_INTEGER_HALF_WORD)(left->bits[0]));
        }
    }

    BigInteger result = bi_create(0);
    for (int i = 0; i < BIG_INTEGER_HALF_WORD_SIZE; ++i) {
        BIG_INTEGER_WORD carry = 0;
        const bool isIEven = ((i & 1) == 0);
        const int i2 = i >> 1;
        const int maxJ = BIG_INTEGER_HALF_WORD_SIZE - i;
        if (isIEven) {
            for (int j = 0; j < maxJ; ++j) {
                const bool isJEven = ((j & 1) == 0);
                const int j2 = j >> 1;
                const int i2j2 = i2 + j2;
                if (isJEven) {
                    BIG_INTEGER_WORD temp =
                        (right->bits[j2] & BIG_INTEGER_HALF_WORD_MASK) * (left->bits[i2] & BIG_INTEGER_HALF_WORD_MASK) +
                        (result.bits[i2j2] & BIG_INTEGER_HALF_WORD_MASK) + carry;
                    carry = temp >> BIG_INTEGER_HALF_WORD_BITS;
                    result.bits[i2j2] =
                        (result.bits[i2j2] & BIG_INTEGER_HALF_WORD_MASK_NOT) | (temp & BIG_INTEGER_HALF_WORD_MASK);
                } else {
                    BIG_INTEGER_WORD temp = (right->bits[j2] >> BIG_INTEGER_HALF_WORD_BITS) *
                            (left->bits[i2] & BIG_INTEGER_HALF_WORD_MASK) +
                        (result.bits[i2j2] >> BIG_INTEGER_HALF_WORD_BITS) + carry;
                    carry = temp >> BIG_INTEGER_HALF_WORD_BITS;
                    result.bits[i2j2] = (result.bits[i2j2] & BIG_INTEGER_HALF_WORD_MASK) |
                        ((temp & BIG_INTEGER_HALF_WORD_MASK) << BIG_INTEGER_HALF_WORD_BITS);
                }
            }
        } else {
            for (int j = 0; j < maxJ; ++j) {
                const bool isJEven = ((j & 1) == 0);
                const int j2 = j >> 1;
                const int i2j2 = isJEven ? (i2 + j2) : (i2 + j2 + 1);
                if (isJEven) {
                    BIG_INTEGER_WORD temp =
                        (right->bits[j2] & BIG_INTEGER_HALF_WORD_MASK) * (left->bits[i2] >> BIG_INTEGER_HALF_WORD_BITS) +
                        (result.bits[i2j2] >> BIG_INTEGER_HALF_WORD_BITS) + carry;
                    carry = temp >> BIG_INTEGER_HALF_WORD_BITS;
                    result.bits[i2j2] = (result.bits[i2j2] & BIG_INTEGER_HALF_WORD_MASK) |
                        ((temp & BIG_INTEGER_HALF_WORD_MASK) << BIG_INTEGER_HALF_WORD_BITS);
                } else {
                    BIG_INTEGER_WORD temp =
                        (right->bits[j2] >> BIG_INTEGER_HALF_WORD_BITS) * (left->bits[i2] >> BIG_INTEGER_HALF_WORD_BITS) +
                        (result.bits[i2j2] & BIG_INTEGER_HALF_WORD_MASK) + carry;
                    carry = temp >> BIG_INTEGER_HALF_WORD_BITS;
                    result.bits[i2j2] =
                        (result.bits[i2j2] & BIG_INTEGER_HALF_WORD_MASK_NOT) | (temp & BIG_INTEGER_HALF_WORD_MASK);
                }
            }
        }
    }

    return result;
}

#if 0
// Adapted from Qrack! (The fundamental algorithm was discovered before.)
// Complexity - O(log)
BigInteger bi_mul(const BigInteger* left, const BigInteger* right)
{
    int rightLog2 = bi_log2(right);
    if (rightLog2 == 0) {
        // right == 1
        return *left;
    }
    int maxI = BIG_INTEGER_BITS - rightLog2;

    BigInteger result;
    bi_set_0(&result);
    for (int i = 0; i < maxI; ++i) {
        BigInteger partMul = bi_lshift(right, i);
        if (bi_compare_0(&partMul) == 0) {
            break;
        }
        const int iWord = i / BIG_INTEGER_WORD_BITS;
        if (1 & (left->bits[iWord] >> (i - (iWord * BIG_INTEGER_WORD_BITS)))) {
            for (int j = iWord; j < BIG_INTEGER_WORD_SIZE; j++) {
                BIG_INTEGER_WORD temp = result.bits[j];
                result.bits[j] += partMul.bits[j];
                int k = j;
                while ((k < BIG_INTEGER_WORD_SIZE) && (temp > result.bits[k])) {
                    temp = result.bits[++k]++;
                }
            }
        }
    }

    return result;
}
#endif

// "Schoolbook division" (on half words)
// Complexity - O(x^2)
void bi_div_mod_small(const BigInteger* left, BIG_INTEGER_HALF_WORD right, BigInteger* quotient, BIG_INTEGER_HALF_WORD* rmndr)
{
    if (quotient) {
        bi_set_0(quotient);
    }
    BIG_INTEGER_WORD carry = 0;
    for (int i = BIG_INTEGER_HALF_WORD_SIZE - 1; i >= 0; --i) {
        const int i2 = i >> 1;
        carry <<= BIG_INTEGER_HALF_WORD_BITS;
        if (i & 1) {
            carry |= left->bits[i2] >> BIG_INTEGER_HALF_WORD_BITS;
            if (quotient) {
                quotient->bits[i2] |= (carry / right) << BIG_INTEGER_HALF_WORD_BITS;
            }
        } else {
            carry |= left->bits[i2] & BIG_INTEGER_HALF_WORD_MASK;
            if (quotient) {
                quotient->bits[i2] |= (carry / right);
            }
        }
        carry %= right;
    }
    if (rmndr) {
        *rmndr = carry;
    }
}

// Adapted from Qrack! (The fundamental algorithm was discovered before.)
// Complexity - O(log)
void bi_div_mod(const BigInteger* left, const BigInteger* right, BigInteger* quotient, BigInteger* rmndr)
{
    const int lrCompare = bi_compare(left, right);

    if (lrCompare < 0) {
        // left < right
        if (quotient) {
            // quotient = 0
            bi_set_0(quotient);
        }
        if (rmndr) {
            // rmndr = left
            bi_copy_ip(left, rmndr);
        }
        return;
    }

    if (lrCompare == 0) {
        // left == right
        if (quotient) {
            // quotient = 1
            bi_set_0(quotient);
            quotient->bits[0] = 1;
        }
        if (rmndr) {
            // rmndr = 0
            bi_set_0(rmndr);
        }
        return;
    }

    // Otherwise, past this point, left > right.

    if (right->bits[0] < BIG_INTEGER_HALF_WORD_POW) {
        int wordSize;
        for (wordSize = 1; wordSize < BIG_INTEGER_WORD_SIZE; ++wordSize) {
            if (right->bits[wordSize]) {
                break;
            }
        }
        if (wordSize >= BIG_INTEGER_WORD_SIZE) {
            // We can use the small division variant.
            if (rmndr) {
                BIG_INTEGER_HALF_WORD t;
                bi_div_mod_small(left, (BIG_INTEGER_HALF_WORD)(right->bits[0]), quotient, &t);
                rmndr->bits[0] = t;
                for (int i = 1; i < BIG_INTEGER_WORD_SIZE; ++i) {
                    rmndr->bits[i] = 0;
                }
            } else {
                bi_div_mod_small(left, (BIG_INTEGER_HALF_WORD)(right->bits[0]), quotient, 0);
            }
            return;
        }
    }

    BigInteger bi1 = bi_create(1U);
    int rightLog2 = bi_log2(right);
    BigInteger rightTest = bi_lshift(&bi1, rightLog2);
    if (bi_compare(right, &rightTest) < 0) {
        ++rightLog2;
    }
    if (quotient) {
        bi_set_0(quotient);
    }
    BigInteger rem;
    bi_copy_ip(left, &rem);

    while (bi_compare(&rem, right) >= 0) {
        int logDiff = bi_log2(&rem) - rightLog2;
        if (logDiff > 0) {
            BigInteger partMul = bi_lshift(right, logDiff);
            BigInteger partQuo = bi_lshift(&bi1, logDiff);
            bi_sub_ip(&rem, &partMul);
            if (quotient) {
                bi_add_ip(quotient, &partQuo);
            }
        } else {
            bi_sub_ip(&rem, right);
            if (quotient) {
                bi_increment(quotient, 1U);
            }
        }
    }
    if (rmndr) {
        *rmndr = rem;
    }
}
